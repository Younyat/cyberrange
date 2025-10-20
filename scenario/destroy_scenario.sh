



#!/usr/bin/env bash
set -euo pipefail

# ===============================
# 🔥 Script: destroy_scenario.sh
# 🧩 Ubicación: /scenario/
# 🧨 Destruye todos los recursos Terraform generados en /tf_out/
# ===============================

# Ruta absoluta del directorio tf_out (ajústala si cambia la estructura)
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tf_out" && pwd)"

# Comprobación básica
if [ ! -d "$TF_DIR" ]; then
  echo "❌ No se encontró el directorio de despliegue: $TF_DIR"
  exit 1
fi

echo "==============================================="
echo "🧨 Iniciando destrucción del escenario Terraform"
echo "📁 Directorio: $TF_DIR"
echo "==============================================="


# Entrar en el directorio tf_out
cd "$TF_DIR"

# Inicializar Terraform si es necesario
if [ ! -d ".terraform" ]; then
  echo "⚙️  Ejecutando 'terraform init'..."
  terraform init -input=false
fi

# Destruir todos los recursos
echo "🚀 Ejecutando 'terraform destroy'..."
terraform destroy -auto-approve -parallelism=4

echo "✅ Recursos Terraform destruidos correctamente."





# Limpieza opcional de archivos residuales
echo "🧹 Eliminando archivos temporales..."
rm -rf .terraform terraform.tfstate terraform.tfstate.backup terraform.lock.hcl terraform_outputs.json


echo "✨ Limpieza completa. Entorno restaurado."
