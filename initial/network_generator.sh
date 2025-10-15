#!/usr/bin/env bash
# ======================================================
# 🚀 Generador de red y router en OpenStack con Terraform
# Crea:
#   - red_externa (10.0.2.0/24)
#   - red_privada (192.168.100.0/24)
#   - router_privado (con gateway externo e interfaz interna)
# Autor: Younes Assouyat
# ======================================================

set -e

TF_FILE="network.tf"

echo "==============================================="
echo "🌐 Generador de redes y router en OpenStack"
echo "==============================================="

# ------------------------------------------------------
# 🧱 1. Verificar instalación de Terraform
# ------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
  echo "📦 Instalando Terraform..."
  sudo apt update -y
  sudo apt install -y curl gnupg lsb-release
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update -y && sudo apt install -y terraform
else
  echo "✅ Terraform ya está instalado."
fi

# ------------------------------------------------------
# 🧾 2. Crear archivo network.tf
# ------------------------------------------------------
echo "📝 Creando archivo Terraform: $TF_FILE ..."

cat > "$TF_FILE" <<'EOF'
##############################################
# 🚀 Infraestructura de Redes y Router en OpenStack
# Redes: red_privada y red_externa
# Router: router_privado
# Autor: Younes Assouyat
##############################################

# -----------------------------
# 🌐 Red Externa (Public/External)
# -----------------------------
resource "openstack_networking_network_v2" "red_externa" {
  name           = "red_externa"
  admin_state_up = true
  shared         = false
  external       = true
}

resource "openstack_networking_subnet_v2" "red_externa_subnet" {
  name            = "red_externa_subnet"
  network_id      = openstack_networking_network_v2.red_externa.id
  cidr            = "10.0.2.0/24"
  ip_version      = 4
  enable_dhcp     = true
  gateway_ip      = "10.0.2.1"
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

# -----------------------------
# 🔒 Red Privada
# -----------------------------
resource "openstack_networking_network_v2" "red_privada" {
  name           = "red_privada"
  admin_state_up = true
  shared         = false
}

resource "openstack_networking_subnet_v2" "red_privada_subnet" {
  name            = "red_privada_subnet"
  network_id      = openstack_networking_network_v2.red_privada.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  enable_dhcp     = true
  gateway_ip      = "192.168.100.1"
  dns_nameservers = ["8.8.8.8", "1.1.1.1"]
}

# -----------------------------
# 🚦 Router Privado
# -----------------------------
resource "openstack_networking_router_v2" "router_privado" {
  name                = "router_privado"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.red_externa.id
}

# Interfaz interna (red_privada)
resource "openstack_networking_router_interface_v2" "router_privado_interface" {
  router_id = openstack_networking_router_v2.router_privado.id
  subnet_id = openstack_networking_subnet_v2.red_privada_subnet.id
}

# -----------------------------
# 📡 Salidas útiles
# -----------------------------
output "router_privado_info" {
  description = "Información del router y redes creadas"
  value = {
    router_name        = openstack_networking_router_v2.router_privado.name
    external_gateway   = openstack_networking_router_v2.router_privado.external_network_id
    internal_interface = openstack_networking_subnet_v2.red_privada_subnet.cidr
  }
}
EOF

echo "✅ Archivo '$TF_FILE' generado correctamente."