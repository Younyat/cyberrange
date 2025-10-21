#!/usr/bin/env bash
# ======================================================
# ⚙️ Generador automático de admin-openrc.sh desde /etc/kolla/clouds.yaml
# Compatible con la versión Python de yq
# Autor: Younes Assouyat
# ======================================================
# Uso:
#   bash generate_app_cred_openrc_from_clouds.sh 2>&1 | tee log_generate_openrc.log
# ======================================================

set -e

KOLLA_CLOUDS="/etc/kolla/clouds.yaml"
TMP_JSON="/tmp/clouds.json"
OUTPUT_FILE="admin-openrc.sh"
CLOUD_NAME="kolla-admin"

echo "==============================================="
echo "🔐 Generador de admin-openrc.sh para OpenStack"
echo "==============================================="

# ------------------------------------------------------
# 🧱 1. Verificar dependencias
# ------------------------------------------------------
if ! command -v yq >/dev/null 2>&1; then
  echo "📦 Instalando yq (Python version)..."
  sudo apt update -y
  sudo apt install -y yq
else
  echo "✅ yq ya está instalado."
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "📦 Instalando jq..."
  sudo apt install -y jq
else
  echo "✅ jq ya está instalado."
fi

# ------------------------------------------------------
# 📘 2. Convertir /etc/kolla/clouds.yaml a JSON
# ------------------------------------------------------
if [ ! -f "$KOLLA_CLOUDS" ]; then
  echo "❌ No se encontró /etc/kolla/clouds.yaml"
  exit 1
fi

echo "✅ Encontrado /etc/kolla/clouds.yaml"
yq -r . "$KOLLA_CLOUDS" > "$TMP_JSON"

# ------------------------------------------------------
# ⚙️ 3. Extraer datos con jq
# ------------------------------------------------------
AUTH_URL=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.auth_url" "$TMP_JSON")
USERNAME=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.username" "$TMP_JSON")
PASSWORD=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.password" "$TMP_JSON")
PROJECT_NAME=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.project_name" "$TMP_JSON")
USER_DOMAIN=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.user_domain_name" "$TMP_JSON")
PROJECT_DOMAIN=$(jq -r ".clouds.\"$CLOUD_NAME\".auth.project_domain_name" "$TMP_JSON")
REGION_NAME=$(jq -r ".clouds.\"$CLOUD_NAME\".region_name" "$TMP_JSON")
INTERFACE=$(jq -r ".clouds.\"$CLOUD_NAME\".interface // \"public\"" "$TMP_JSON")

if [ -z "$AUTH_URL" ] || [ "$AUTH_URL" = "null" ]; then
  echo "❌ Error: No se pudo leer la configuración del cloud '$CLOUD_NAME' en $KOLLA_CLOUDS."
  exit 1
fi

# ------------------------------------------------------
# 🧾 4. Generar admin-openrc.sh
# ------------------------------------------------------
cat > "$OUTPUT_FILE" <<EOF
#!/bin/bash
# ======================================================
# 🧩 Archivo de credenciales para OpenStack
# Generado automáticamente desde $KOLLA_CLOUDS
# Cloud seleccionado: $CLOUD_NAME
# ======================================================

# ------------------------------------------------------
# 🧹 Limpiar variables previas del entorno
# ------------------------------------------------------
unset OS_AUTH_TYPE
unset OS_AUTH_URL
unset OS_USERNAME
unset OS_PASSWORD
unset OS_USER_DOMAIN_NAME
unset OS_PROJECT_NAME
unset OS_PROJECT_DOMAIN_NAME
unset OS_REGION_NAME
unset OS_APPLICATION_CREDENTIAL_ID
unset OS_APPLICATION_CREDENTIAL_SECRET
unset OS_APPLICATION_CREDENTIAL_NAME

# ------------------------------------------------------
# 🔐 Configuración de credenciales
# ------------------------------------------------------
export OS_AUTH_URL=$AUTH_URL
export OS_PROJECT_NAME=${PROJECT_NAME:-admin}
export OS_PROJECT_DOMAIN_NAME=${PROJECT_DOMAIN:-Default}
export OS_USERNAME=$USERNAME
export OS_USER_DOMAIN_NAME=${USER_DOMAIN:-Default}
export OS_PASSWORD=$PASSWORD
export OS_INTERFACE=$INTERFACE
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=${REGION_NAME:-RegionOne}

echo "✅ Credenciales OpenStack cargadas para \$OS_PROJECT_NAME (\$OS_USERNAME)"
EOF

chmod +x "$OUTPUT_FILE"

echo "✅ Archivo '$OUTPUT_FILE' generado correctamente."
echo "📂 Contenido:"
echo "-----------------------------------------------"
cat "$OUTPUT_FILE"
echo "-----------------------------------------------"
echo ""
echo "🔧 Puedes usarlo con:"
echo "   source $OUTPUT_FILE"
