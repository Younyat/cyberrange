#!/bin/bash
#!/bin/bash  bash openstack-installer.sh 2>&1 | tee nombre_del_log.log

# ============================================================
# Script completo: Instalación OpenStack + Kolla-Ansible
# ============================================================

set -euo pipefail
set -x  # Muestra cada comando ejecutado para debug

# ============================================================
# 🧠 Detección, creación y activación del entorno virtual del usuario real
# ============================================================

# Detectar el usuario real, incluso si el script se ejecuta con sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
VENV_PATH="$REAL_HOME/openstack_venv"
VENV_ACTIVATE="$VENV_PATH/bin/activate"

echo "==============================================="
echo "🧩 Detección y configuración del entorno virtual"
echo "==============================================="

# ------------------------------------------------------------
# 🧩 Asegurar dependencias del sistema para Python y virtualenv
# ------------------------------------------------------------
echo "🔹 Verificando dependencias de Python..."
sudo apt update -y
sudo apt install -y \
  python3-pip \
  python3-venv \
  python3-dev \
  python3.12-venv \
  libffi-dev \
  libssl-dev \
  build-essential \
  pkg-config \
  libdbus-1-dev \
  libglib2.0-dev || {
    echo "⚠️ Error al instalar dependencias base de Python."
    echo "🔁 Intentando reparar..."
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y
  }

# ------------------------------------------------------------
# 🧩 Crear o activar entorno virtual
# ------------------------------------------------------------
if [[ -d "$VENV_PATH" && -f "$VENV_ACTIVATE" ]]; then
  echo "✅ Entorno virtual encontrado en: $VENV_PATH"
else
  echo "⚙️ Creando nuevo entorno virtual en: $VENV_PATH"
  python3 -m venv "$VENV_PATH" || {
    echo "❌ Error al crear el entorno virtual. Verifica que python3-venv esté instalado."
    exit 1
  }
fi

# Activar entorno virtual
source "$VENV_ACTIVATE"
export PATH="$VENV_PATH/bin:$PATH"

# ------------------------------------------------------------
# 🧩 Actualizar herramientas esenciales de Python
# ------------------------------------------------------------
echo "🔧 Actualizando pip, setuptools y wheel..."
pip install --upgrade pip setuptools wheel || {
  echo "⚠️ Error al actualizar herramientas de Python. Continuando..."
}

# ------------------------------------------------------------
# 🧩 Verificar módulo dbus-python (requerido por Kolla-Ansible)
# ------------------------------------------------------------
echo "🔍 Verificando instalación de dbus-python..."
if ! python3 -c "import dbus" &>/dev/null; then
  echo "⚙️ Instalando dependencias del sistema para dbus-python..."
  sudo apt install -y libdbus-1-dev libglib2.0-dev pkg-config
  pip install dbus-python==1.4.0 || {
    echo "❌ Error al instalar dbus-python. Abortando..."
    exit 1
  }
else
  echo "✅ dbus-python ya disponible en el entorno virtual."
fi

echo "🚀 Entorno virtual listo y activo para continuar con la instalación."

# ============================================================
# ⚙️ Instalación de dependencias básicas del sistema
# ============================================================
echo "🔹 Instalando dependencias base del sistema..."
sudo apt install -y \
  git \
  iptables \
  bridge-utils \
  wget \
  curl \
  dbus \
  ca-certificates \
  gnupg \
  apt-transport-https \
  software-properties-common || {
    echo "⚠️ Error detectado durante la instalación de dependencias base. Intentando reparar..."
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y
  }

# ============================================================
# 🐳 Configuración Docker y Terraform
# ============================================================
echo "🔹 Configurando Docker y Terraform..."

# Limpiar configuración previa
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -rf /etc/apt/keyrings/docker.asc
sudo mkdir -p /usr/share/keyrings

# Repositorio Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt update -y
sudo snap install terraform --classic
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Habilitar servicios
echo "🔹 Habilitando servicios Docker y D-Bus..."
sudo systemctl daemon-reexec || true
sudo systemctl enable docker --now || {
  echo "⚠️ Docker no se pudo iniciar automáticamente. Intentando reiniciar..."
  sudo systemctl restart docker || echo "⚠️ Docker sigue detenido. Verifica manualmente más tarde."
}
sudo systemctl enable dbus --now || true

# Añadir usuario al grupo Docker
echo "👤 Añadiendo usuario '$REAL_USER' al grupo docker..."
sudo usermod -aG docker "$REAL_USER"

echo "✅ Dependencias del sistema y entorno virtual configurados correctamente."





pip install --upgrade pip setuptools wheel

# 2️⃣.1 Instalación de dependencias Python específicas
echo "🔹 Instalando dependencias Python específicas para OpenStack y Kolla-Ansible..."

# Crear un archivo temporal con las dependencias
cat << 'EOF' > requirements.txt
ansible==11.5.0
ansible-core==2.18.5
autopage==0.5.2
bcrypt==4.3.0
blinker==1.9.0
certifi==2025.4.26
cffi==1.17.1
charset-normalizer==3.4.2
click==8.3.0
cliff==4.9.1
cmd2==2.5.11
cryptography==43.0.3
dbus-python==1.4.0
debtcollector==3.0.0
decorator==5.2.1
docker==7.1.0
dogpile.cache==1.4.0
Flask==3.1.2
flask-cors==6.0.1
hvac==2.3.0
idna==3.10
iso8601==2.1.0
itsdangerous==2.2.0
Jinja2==3.1.6
jmespath==1.0.1
jsonpatch==1.33
jsonpointer==3.0.0
keystoneauth1==5.10.0
kolla-ansible @ git+https://opendev.org/openstack/kolla-ansible@6f27840cd46c1384d3e034aa670d76422d5be9b5
MarkupSafe==3.0.2
msgpack==1.1.0
netaddr==1.3.0
openstacksdk==4.5.0
os-service-types==1.7.0
osc-lib==4.0.0
oslo.config==9.7.1
oslo.i18n==6.5.1
oslo.serialization==5.7.0
oslo.utils==8.2.0
packaging==25.0
passlib==1.7.4
pbr==6.1.1
platformdirs==4.3.7
prettytable==3.16.0
psutil==7.0.0
pycparser==2.22
pyparsing==3.2.3
pyperclip==1.9.0
python-cinderclient==9.7.0
python-keystoneclient==5.6.0
python-openstackclient==8.0.0
PyYAML==6.0.2
requests==2.32.3
requestsexceptions==1.4.0
resolvelib==0.8.1
rfc3986==2.0.0
setuptools==80.4.0
stevedore==5.4.1
typing_extensions==4.13.2
tzdata==2025.2
urllib3==1.26.20
wcwidth==0.2.13
Werkzeug==3.1.3
wrapt==1.17.2
EOF

# Instalar todas las dependencias
pip install -r requirements.txt --no-cache-dir

echo "✅ Dependencias Python instaladas correctamente."

# ============================================================
# 🚀 launch-veth-persistent.sh integrado (red persistente)
# ============================================================
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$CURRENT_DIR/setup-veth.sh"
SERVICE_FILE="/etc/systemd/system/setup-veth.service"
LOG_FILE="/var/log/setup-veth.log"

if [[ "$CURRENT_DIR" == *" "* ]]; then
  SAFE_DIR="$REAL_HOME/launch-veth-persistent"
  mkdir -p "$SAFE_DIR"
  cp -f "$SETUP_SCRIPT" "$SAFE_DIR/"
  cp -f "$0" "$SAFE_DIR/"
  chmod +x "$SAFE_DIR/setup-veth.sh" "$SAFE_DIR/$(basename "$0")"
  echo "⚠️  Ruta con espacios detectada. Scripts movidos a $SAFE_DIR"
  echo "🔁 Reejecutando desde $SAFE_DIR..."
  exec sudo bash "$SAFE_DIR/$(basename "$0")"
  exit 0
else
  SAFE_DIR="$CURRENT_DIR"
fi
SAFE_SCRIPT="$SAFE_DIR/setup-veth.sh"

echo "🔍 Verificando existencia de $SETUP_SCRIPT..."
if [ ! -f "$SETUP_SCRIPT" ]; then
  echo "❌ Error: No se encuentra $SETUP_SCRIPT"
  exit 1
fi

echo "🚀 Ejecutando configuración inicial de red..."
sudo bash "$SETUP_SCRIPT" || true

echo "🧩 Creando servicio systemd persistente..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Configurar red virtual uplinkbridge + veth0/veth1 (persistente)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 5
ExecStart=/bin/bash $SAFE_SCRIPT
Restart=on-failure
RemainAfterExit=yes
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 644 "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo chmod +x "$SAFE_SCRIPT"
sudo chown root:root "$SAFE_SCRIPT"
sudo systemctl disable setup-veth.service --now 2>/dev/null || true
sudo systemctl enable setup-veth.service
sudo systemctl restart setup-veth.service
sudo systemctl status setup-veth.service --no-pager -l || true
echo "🎯 Red virtual persistente lista tras reinicios."

# ============================================================
# 4️⃣ Copiar configuración base de Kolla-Ansible
# ============================================================
KOLLA_EXAMPLES="$VENV_PATH/share/kolla-ansible/etc_examples/kolla"
KOLLA_INVENTORY="$VENV_PATH/share/kolla-ansible/ansible/inventory"
sudo mkdir -p /etc/kolla /etc/kolla/ansible/inventory
sudo chown -R "$REAL_USER:$REAL_USER" /etc/kolla

cp "$KOLLA_EXAMPLES/globals.yml" "$KOLLA_EXAMPLES/passwords.yml" /etc/kolla
cp "$KOLLA_INVENTORY/all-in-one" ./all-in-one
echo "✅ Archivos globals.yml, passwords.yml y all-in-one copiados."

# ============================================================
# 5️⃣ Configuración de red y globals.yml
# ============================================================
echo "🔍 Detectando interfaz de red principal..."
MAIN_IFACE=$(ip -o link show | awk -F': ' '!/lo|veth|br-|docker|virbr|tap/ && /state UP/ {print $2; exit}')
[ -z "$MAIN_IFACE" ] && MAIN_IFACE="ens33"
echo "✅ Interfaz detectada: $MAIN_IFACE"

sudo chown "$REAL_USER:$REAL_USER" /etc/kolla/passwords.yml
kolla-genpwd || true

SUBNET="192.168.0"
for i in $(seq 10 50); do
  IP="$SUBNET.$i"
  if ! ping -c 1 -W 1 "$IP" &>/dev/null; then
    VIP="$IP"
    break
  fi
done

sudo tee /etc/kolla/globals.yml > /dev/null <<EOF
kolla_base_distro: "ubuntu"
network_interface: "$MAIN_IFACE"
neutron_external_interface: "veth1"
kolla_internal_vip_address: "$VIP"
EOF

# ============================================================
# 6️⃣ Despliegue de Kolla-Ansible
# ============================================================
kolla-ansible install-deps
kolla-ansible bootstrap-servers -i ./all-in-one
kolla-ansible prechecks -i ./all-in-one
kolla-ansible deploy -i ./all-in-one

# ============================================================
# 7️⃣ Post-deploy y cliente OpenStack
# ============================================================
if [ ! -f /etc/kolla/ansible/inventory/all-in-one ]; then
  sudo mkdir -p /etc/kolla/ansible/inventory
  sudo cp "$CURRENT_DIR/all-in-one" /etc/kolla/ansible/inventory/
fi

kolla-ansible post-deploy
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/master
openstack --version

echo "✅ Instalación completa de OpenStack + red persistente."