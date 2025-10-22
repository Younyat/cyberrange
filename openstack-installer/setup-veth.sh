#!/bin/bash
set -euo pipefail

BRIDGE="uplinkbridge"
VETH0="veth0"
VETH1="veth1"
SUBNET="10.0.2.0/24"
GATEWAY="10.0.2.1"
EXT_IF="ens33"



sudo apt update -y
sudo apt install -y iproute2 net-tools bridge-utils

echo "🔧 Configurando red virtual para OpenStack..."

# Eliminar configuración previa si existe
if ip link show "$BRIDGE" &>/dev/null; then
  echo "⚠️  Eliminando bridge existente $BRIDGE..."
  ip link set "$BRIDGE" down || true
  brctl delbr "$BRIDGE" || true
fi
ip link del "$VETH0" type veth &>/dev/null || true
ip link del "$VETH1" type veth &>/dev/null || true

# Crear par veth
ip link add "$VETH0" type veth peer name "$VETH1"
ip link set "$VETH0" up
ip link set "$VETH1" up

# Crear bridge y añadir interfaz
brctl addbr "$BRIDGE"
brctl addif "$BRIDGE" "$VETH0"
ip addr add "$GATEWAY/24" dev "$BRIDGE"
ip link set "$BRIDGE" up

# Configurar NAT
iptables -t nat -A POSTROUTING -o "$EXT_IF" -s "$SUBNET" -j MASQUERADE
iptables -A FORWARD -s "$SUBNET" -j ACCEPT

echo "✅ Red virtual configurada:"
echo "   Bridge: $BRIDGE ($GATEWAY)"
echo "   Veths:  $VETH0 <-> $VETH1"