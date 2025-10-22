#!/bin/bash
#!/bin/bash  bash openstack-installer.sh 2>&1 | tee nombre_del_log.log

# app-cred-app-openrc.sh->http://192.168.0.11/identity/application_credentials/create/
# ============================================================
# Script completo: Instalación OpenStack + Kolla-Ansible
# ============================================================

set -euo pipefail
set -x  # Muestra cada comando ejecutado para debug

echo "🚀 Iniciando automatización de instalación..."

# ============================================================
# 1️⃣ Preparación del sistema
# ============================================================
echo "🔹 Actualizando paquetes del sistema..."
sudo apt update -y
sudo apt upgrade -y

echo "🔹 Instalando dependencias básicas..."
sudo apt install -y git python3-dev python3-venv libffi-dev gcc libssl-dev \
iptables bridge-utils wget curl dbus pkg-config libdbus-1-dev libglib2.0-dev sudo gnupg \
apt-transport-https ca-certificates software-properties-common

# ============================================================
# 2️⃣ Configuración Docker (remueve posibles conflictos)
# ============================================================
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -rf /etc/apt/keyrings/docker.asc
sudo mkdir -p /usr/share/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt update -y
sudo snap install terraform --classic

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker --now
sudo usermod -aG docker "$USER"

# ============================================================
# 3️⃣ Crear entorno virtual
# ============================================================
VENV_PATH="$HOME/openstack_venv"
echo "🔹 Creando entorno virtual en $VENV_PATH..."
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

# ============================================================
# 4️⃣ Instalación de dependencias Python y Kolla-Ansible
# ============================================================
REQ_FILE="$HOME/requirements.txt"
cat << 'EOF' > "$REQ_FILE"
ansible==11.5.0
ansible-core==2.18.5
autopage==0.5.2
bcrypt==4.3.0
bidict==0.23.1
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
dnspython==2.8.0
docker==7.1.0
dogpile.cache==1.4.0
eventlet==0.40.3
Flask==3.1.2
flask-cors==6.0.1
Flask-SocketIO==5.5.1
greenlet==3.2.4
h11==0.16.0
hvac==2.3.0
idna==3.10
invoke==2.2.0
iso8601==2.1.0
itsdangerous==2.2.0
Jinja2==3.1.6
jmespath==1.0.1
jsonpatch==1.33
jsonpointer==3.0.0
keystoneauth1==5.10.0
kolla-ansible @ git+https://opendev.org/openstack/kolla-ansible@master
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
paramiko==4.0.0
passlib==1.7.4
pbr==6.1.1
platformdirs==4.3.7
prettytable==3.16.0
psutil==7.0.0
pycparser==2.22
PyNaCl==1.6.0
pyparsing==3.2.3
pyperclip==1.9.0
python-cinderclient==9.7.0
python-engineio==4.12.3
python-keystoneclient==5.6.0
python-openstackclient==8.0.0
python-socketio==5.14.1
PyYAML==6.0.2
requests==2.32.3
requestsexceptions==1.4.0
resolvelib==0.8.1
rfc3986==2.0.0
setuptools==80.4.0
simple-websocket==1.1.0
stevedore==5.4.1
typing_extensions==4.13.2
tzdata==2025.2
urllib3==1.26.20
wcwidth==0.2.13
Werkzeug==3.1.3
wrapt==1.17.2
wsproto==1.2.0
EOF

pip install -r "$REQ_FILE" --no-cache-dir
echo "✅ Dependencias Python instaladas correctamente."

# ============================================================
# 🚀 launch-veth-persistent.sh integrado
# ============================================================
# --- Variables ---
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$CURRENT_DIR/setup-veth.sh"
SERVICE_FILE="/etc/systemd/system/setup-veth.service"
LOG_FILE="/var/log/setup-veth.log"

# Si la ruta tiene espacios, mover los scripts a una ubicación segura.
if [[ "$CURRENT_DIR" == *" "* ]]; then
  SAFE_DIR="$HOME/launch-veth-persistent"
  mkdir -p "$SAFE_DIR"
  cp -f "$SETUP_SCRIPT" "$SAFE_DIR/"
  cp -f "$0" "$SAFE_DIR/"
  chmod +x "$SAFE_DIR/setup-veth.sh" "$SAFE_DIR/$(basename "$0")"
  echo "⚠️  Ruta con espacios detectada. Scripts movidos a $SAFE_DIR"
  echo "🔁 Reejecutando desde $SAFE_DIR..."
  exec sudo bash "$SAFE_DIR/$(basename "$0")"
  exit 0
else
  # Si no hay espacios, trabajar directamente en el directorio actual
  SAFE_DIR="$CURRENT_DIR"
fi

SAFE_SCRIPT="$SAFE_DIR/setup-veth.sh"




# --- Detectar espacios en la ruta actual ---
if [[ "$CURRENT_DIR" == *" "* ]]; then
  echo "⚠️  Se detectó un espacio en la ruta actual: $CURRENT_DIR"
  echo "➡️  Moviendo scripts a $SAFE_DIR ..."
  mkdir -p "$SAFE_DIR"
  cp -f "$SETUP_SCRIPT" "$SAFE_DIR/"
  cp -f "$0" "$SAFE_DIR/"
  chmod +x "$SAFE_SCRIPT" "$SAFE_DIR/$(basename "$0")"
  echo "✅ Scripts movidos a ruta segura sin espacios."
  echo "🔁 Reejecutando desde $SAFE_DIR ..."
  exec sudo bash "$SAFE_DIR/$(basename "$0")"
  exit 0
fi

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
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStartPre=/usr/bin/sleep 5
ExecStart=/bin/bash $SAFE_SCRIPT
ExecStartPost=/usr/bin/logger "✅ uplinkbridge inicializado correctamente"
Restart=on-failure
RemainAfterExit=yes
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

echo "🔧 Activando servicio systemd..."
sudo chmod 644 "$SERVICE_FILE"
sudo systemctl daemon-reload

sudo chmod +x "$SAFE_SCRIPT"
sudo chown root:root "$SAFE_SCRIPT"

sudo systemctl disable setup-veth.service --now 2>/dev/null || true
sudo systemctl enable setup-veth.service
sudo systemctl restart setup-veth.service

echo
sudo systemctl status setup-veth.service --no-pager -l || true
echo
ip addr show uplinkbridge 2>/dev/null || echo "⚠️ uplinkbridge aún no detectado."
echo

if ! systemctl is-active --quiet setup-veth.service; then
    echo "⚠️  El servicio setup-veth.service no se inició correctamente."
    echo "🧾 Últimos logs relevantes:"
    sudo journalctl -xeu setup-veth.service | tail -n 15
else
    echo "🎯 Red virtual persistente lista tras reinicios."
fi

# ============================================================
# 5️⃣ Copiar ejemplos y configuración de Kolla-Ansible
# ============================================================
KOLLA_EXAMPLES="$VENV_PATH/share/kolla-ansible/etc_examples/kolla"
KOLLA_INVENTORY="$VENV_PATH/share/kolla-ansible/ansible/inventory"

sudo mkdir -p /etc/kolla /etc/kolla/ansible/inventory
sudo chown -R "$USER:$USER" /etc/kolla

cp "$KOLLA_EXAMPLES/globals.yml" "$KOLLA_EXAMPLES/passwords.yml" /etc/kolla
cp "$KOLLA_INVENTORY/all-in-one" ./all-in-one
echo "✅ Archivos globals.yml, passwords.yml y all-in-one copiados."

# ============================================================
# 🧠 Detección automática de interfaz principal
# ============================================================
echo "🔍 Detectando interfaz de red principal (para network_interface)..."
MAIN_IFACE=$(ip -o link show | awk -F': ' '!/lo|veth|br-|docker|virbr|tap/ && /state UP/ {print $2; exit}')
if [ -z "$MAIN_IFACE" ]; then
  MAIN_IFACE=$(ip -o link show | awk -F': ' '!/lo|veth|br-|docker|virbr|tap/ {print $2; exit}')
fi
if [ -z "$MAIN_IFACE" ]; then
  echo "❌ No se pudo detectar ninguna interfaz de red válida."
  exit 1
fi
echo "✅ Interfaz detectada: $MAIN_IFACE"
NETWORK_INTERFACE="$MAIN_IFACE"

# ============================================================
# 6️⃣ Generar passwords y configurar globals.yml
# ============================================================
sudo chown "$USER:$USER" /etc/kolla/passwords.yml
kolla-genpwd || true

SUBNET="192.168.0"
START=10
END=50
VIP=""
echo "🔍 Buscando una IP libre..."
for i in $(seq $START $END); do
    IP="$SUBNET.$i"
    if ! ping -c 1 -W 1 "$IP" &>/dev/null; then
        VIP="$IP"
        echo "✅ IP libre encontrada: $VIP"
        break
    fi
done
[ -z "$VIP" ] && { echo "❌ No se encontró IP libre"; exit 1; }

sudo tee /etc/kolla/globals.yml > /dev/null <<EOF
kolla_base_distro: "ubuntu"
network_interface: "$NETWORK_INTERFACE"
neutron_external_interface: "veth1"
kolla_internal_vip_address: "$VIP"
EOF

sudo chown "$USER:$USER" /etc/kolla/globals.yml

# ============================================================
# 7️⃣ Despliegue Kolla-Ansible
# ============================================================
kolla-ansible install-deps
kolla-ansible bootstrap-servers -i ./all-in-one
kolla-ansible prechecks -i ./all-in-one
kolla-ansible deploy -i ./all-in-one
kolla-ansible post-deploy

# ============================================================
# 8️⃣ Cliente OpenStack
# ============================================================
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/master
openstack --version
