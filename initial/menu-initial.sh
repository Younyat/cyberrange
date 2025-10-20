#!/bin/bash
# ======================================================
# 🧩 Generador principal de archivos Terraform
# Incluye:
#   - Limpieza total del entorno OpenStack (opcional)
#   - Provider dinámico (desde /etc/kolla/clouds.yaml)
#   - Generación de imágenes, redes y flavors
# Autor: Younes Assouyat
# ======================================================

set -e

BASE_DIR=$(pwd)
PROVIDER_FILE="$BASE_DIR/provider.tf"
GEN_PROVIDER_SCRIPT="./generate_provider_from_clouds.sh"
CLEAN_SCRIPT="./openstack_full_cleanup.sh"

echo "==============================================="
echo "🚀 Iniciando generador principal de Terraform"
echo "==============================================="

# ------------------------------------------------------
# 🧹 0️⃣ Limpieza de scripts y permisos de ejecución
# ------------------------------------------------------
echo "🔧 Verificando y corrigiendo scripts locales..."

for script in generate_provider_from_clouds.sh debian-linux.sh ubuntu-linux.sh flavors.sh network_generator.sh openstack_full_cleanup.sh; do
  if [[ -f "./$script" ]]; then
    echo "🧩 Corrigiendo $script ..."
    # 🔹 Eliminar BOM UTF-8 si existe
    sed -i '1s/^\xEF\xBB\xBF//' "./$script" 2>/dev/null
    # 🔹 Convertir formato DOS a UNIX si hay saltos de línea CRLF
    sed -i 's/\r$//' "./$script" 2>/dev/null
    # 🔹 Asegurar permisos de ejecución
    chmod +x "./$script"
  fi
done

echo "✅ Scripts corregidos y permisos aplicados."
echo ""

# ------------------------------------------------------
# 🔥 0.5️⃣ Preguntar si se desea limpiar OpenStack antes
# ------------------------------------------------------
if [[ -f "$CLEAN_SCRIPT" ]]; then
  echo "⚠️  Antes de generar los archivos Terraform, puedes limpiar completamente tu entorno OpenStack."
  read -p "¿Deseas ejecutar el script de limpieza total (y/n)? " confirm_cleanup
  if [[ "$confirm_cleanup" == "y" || "$confirm_cleanup" == "Y" ]]; then
    echo "🧹 Ejecutando limpieza completa de OpenStack..."
    sudo "$CLEAN_SCRIPT"
    echo "✅ Limpieza completada."
  else
    echo "⏭️  Limpieza omitida. Continuando..."
  fi
else
  echo "⚠️  Script de limpieza ($CLEAN_SCRIPT) no encontrado. Se omitirá este paso."
fi

# ------------------------------------------------------
# 1️⃣ Comprobar si existe clouds.yaml y script generador
# ------------------------------------------------------
if [[ -f "/etc/kolla/clouds.yaml" && -f "$GEN_PROVIDER_SCRIPT" ]]; then
    echo "✅ Detectado clouds.yaml en /etc/kolla y script generador."
    echo "🔧 Ejecutando $GEN_PROVIDER_SCRIPT ..."
    bash "$GEN_PROVIDER_SCRIPT"
else
    echo "⚠️ No se encontró /etc/kolla/clouds.yaml o el script $GEN_PROVIDER_SCRIPT."
    echo "🚫 No se generará provider.tf hasta que existan ambos archivos."
    echo "   ➜ Asegúrate de tener:"
    echo "     - /etc/kolla/clouds.yaml"
    echo "     - generate_provider_from_clouds.sh"
    echo ""
    echo "   Luego vuelve a ejecutar:"
    echo "     bash menu-initial.sh"
    echo ""
    exit 1
fi

# ------------------------------------------------------
# 2️⃣ Menú de generación de imágenes, redes y sabores
# ------------------------------------------------------
echo ""
echo "=== Seleccione las imágenes que desea crear ==="
echo "1) Solo Debian"
echo "2) Solo Ubuntu"
echo "3) Ambas (Debian y Ubuntu)"
read -p "Ingrese su opción [1-3]: " image_choice

read -p "¿Desea crear los ficheros de redes interna/externa? [s/n]: " network_choice
read -p "¿Desea crear los ficheros de sabores (flavors)? [s/n]: " flavors_choice
echo "---"

# ------------------------------------------------------
# 3️⃣ Ejecutar scripts según la elección
# ------------------------------------------------------
if [[ "$image_choice" == "1" || "$image_choice" == "3" ]]; then
    if [[ -f "./debian-linux.sh" ]]; then
        echo "💽 Ejecutando script para imagen de Debian..."
        ./debian-linux.sh
    else
        echo "⚠️ Script debian-linux.sh no encontrado."
    fi
fi

if [[ "$image_choice" == "2" || "$image_choice" == "3" ]]; then
    if [[ -f "./ubuntu-linux.sh" ]]; then
        echo "💽 Ejecutando script para imagen de Ubuntu..."
        ./ubuntu-linux.sh
    else
        echo "⚠️ Script ubuntu-linux.sh no encontrado."
    fi
fi

if [[ "$flavors_choice" == "s" || "$flavors_choice" == "S" ]]; then
    if [[ -f "./flavors.sh" ]]; then
        echo "⚙️ Ejecutando script para crear sabores..."
        ./flavors.sh
    else
        echo "⚠️ Script flavors.sh no encontrado."
    fi
fi

if [[ "$network_choice" == "s" || "$network_choice" == "S" ]]; then
    if [[ -f "./network_generator.sh" ]]; then
        echo "🌐 Ejecutando script para generar redes y router..."
        ./network_generator.sh
    else
        echo "⚠️ Script network_generator.sh no encontrado."
    fi
fi

# ------------------------------------------------------
# 4️⃣ Finalización
# ------------------------------------------------------
echo "---"
echo "✅ Proceso completado."
echo "🧱 Archivos Terraform generados según su selección."
echo "📦 Ahora puede ejecutar:"
echo "   terraform init"
echo "   terraform apply"
echo "   terraform apply -auto-approve -parallelism=4"
echo "para aplicar los cambios en OpenStack."
