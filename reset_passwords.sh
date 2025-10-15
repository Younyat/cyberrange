#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Configurables
# -------------------------
BASE_DIR="${BASE_DIR:-$(pwd)}"        # usa variable de entorno BASE_DIR si existe, si no pwd
PRIVATE_KEY="${BASE_DIR}/tf_out/nueva_clave_wazuh"
SSH_USER="ubuntu"                     # usuario usado para conectar y ejecutar sudo
SSH_PORT=22
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"

# -------------------------
# Utilidades
# -------------------------
die(){ echo "ERROR: $*" >&2; exit 1; }
info(){ echo "INFO: $*"; }

# Comprueba fuerza mínima de contraseña (simple)
is_password_strong(){
  local pw="$1"
  # mínimo 10 caracteres, al menos una mayúscula, una minúscula y un dígito
  [[ ${#pw} -ge 10 ]] || return 1
  [[ $pw =~ [A-Z] ]] || return 1
  [[ $pw =~ [a-z] ]] || return 1
  [[ $pw =~ [0-9] ]] || return 1
  return 0
}

generate_password(){
  # genera 16 caracteres seguros
  openssl rand -base64 24 | tr -d '/+' | cut -c1-16
}

run_ssh(){
  local target="$1"; shift
  ssh -i "$PRIVATE_KEY" $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@${target}" "$@"
}

run_ssh_sudo(){
  local target="$1"; shift
  # ejecuta el resto como comando remoto (comillas cuidadas)
  ssh -i "$PRIVATE_KEY" $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@${target}" "sudo bash -c '$*'"
}

# -------------------------
# Parseo simple de args
# -------------------------
if [ "$#" -lt 1 ]; then
  cat <<EOF
Uso: $0 <instancia_ip1> [instancia_ip2 ...] [--user USUARIO] [--password PASS] [--force-weak]
Ejemplo: $0 10.0.0.5 10.0.0.6 --user admin
EOF
  exit 1
fi

# argumentos por defecto
TARGETS=()
TARGET_USER="admin"
TARGET_PASS=""
FORCE_WEAK=0

# parsea args simples: recoge IPs hasta encontrar --...
while (( "$#" )); do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2;;
    --password) TARGET_PASS="$2"; shift 2;;
    --force-weak) FORCE_WEAK=1; shift;;
    --*) die "Opción desconocida: $1";;
    *) TARGETS+=("$1"); shift;;
  esac
done

[ -f "$PRIVATE_KEY" ] || die "No se encuentra la clave privada en: $PRIVATE_KEY"

# si se pasó contraseña, valida
if [ -n "$TARGET_PASS" ] && [ "$FORCE_WEAK" -eq 0 ]; then
  if ! is_password_strong "$TARGET_PASS"; then
    echo "AVISO: La contraseña pasada no cumple la política mínima. Se generará una contraseña fuerte en su lugar."
    TARGET_PASS="$(generate_password)"
  fi
elif [ -z "$TARGET_PASS" ]; then
  TARGET_PASS="$(generate_password)"
  info "No se proporcionó contraseña; se generó una segura automáticamente."
fi

# Si todavía es débil y user forzó, aceptamos (no recomendado)
if [ "$FORCE_WEAK" -eq 1 ]; then
  info "--force-weak activado: se aplicará la contraseña tal cual."
fi

# -------------------------
# Loop sobre targets
# -------------------------
echo "Iniciando reset de contraseña para usuario '${TARGET_USER}' en ${#TARGETS[@]} instancia(s)."
RESULTS_FILE="./reset_passwords_results_$(date +%Y%m%d%H%M%S).txt"
echo "Instancia,Usuario,Resultado,Detalles" > "$RESULTS_FILE"

for ip in "${TARGETS[@]}"; do
  echo "----"
  info "Procesando: $ip"

  # 1) comprueba conexión SSH con la clave
  if ! ssh -i "$PRIVATE_KEY" $SSH_OPTS -p "$SSH_PORT" "${SSH_USER}@${ip}" "echo ok" >/dev/null 2>&1; then
    echo "$ip,$TARGET_USER,FAILED,No se puede conectar por SSH con ${SSH_USER}" >> "$RESULTS_FILE"
    warn="No se pudo conectar por SSH a $ip con la clave especificada."
    echo "ERROR: $warn"
    continue
  fi

  # 2) Asegurarse de que existe el usuario remoto; si no, crear
  if run_ssh "$ip" "id -u ${TARGET_USER} >/dev/null 2>&1"; then
    info "Usuario ${TARGET_USER} existe en ${ip}."
  else
    info "Usuario ${TARGET_USER} no existe en ${ip}, se creará."
    run_ssh_sudo "$ip" "useradd -m -s /bin/bash ${TARGET_USER} || true"
  fi

  # 3) Hacer backup del archivo shadow/passwd por si acaso
  BACKUP_TS="$(date +%Y%m%d%H%M%S)"
  run_ssh_sudo "$ip" "cp /etc/shadow /tmp/shadow.backup.${BACKUP_TS} || true"

  # 4) Aplicar la contraseña con chpasswd
  #    Escapamos la contraseña simple (evitar interpretar comillas)
  #    Usamos EOF remoto para evitar problemas con caracteres especiales
  cmd="echo '${TARGET_USER}:${TARGET_PASS}' | chpasswd"
  if run_ssh_sudo "$ip" "$cmd"; then
    info "Contraseña aplicada en ${ip} para ${TARGET_USER}."
    echo "$ip,$TARGET_USER,OK,Contraseña cambiada" >> "$RESULTS_FILE"
  else
    echo "$ip,$TARGET_USER,FAILED,Error al establecer contraseña" >> "$RESULTS_FILE"
    echo "ERROR: No se pudo establecer la contraseña en $ip"
    continue
  fi

  # 5) Opcional: forzar cambio en primer login (comentar si no se desea)
  run_ssh_sudo "$ip" "chage -d 0 ${TARGET_USER} || true"

done

echo
echo "Proceso finalizado. Resultados guardados en: $RESULTS_FILE"
echo "Usuario objetivo: $TARGET_USER"
echo "Contraseña aplicada (para todas las instancias): $TARGET_PASS"
echo
echo "NOTAS:"
echo "- Revisa $RESULTS_FILE para ver el detalle por instancia."
echo "- Si necesitas que la contraseña sea distinta por instancia, pásala manualmente con --password."
echo "- Evita usar contraseñas débiles; usa gestores de contraseñas."
