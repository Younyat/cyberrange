# 🧩 Guía de Despliegue Automatizado de OpenStack y Dashboard UMA

Este documento describe cómo desplegar de forma completamente automatizada un entorno **OpenStack all-in-one** mediante **Kolla-Ansible**, incluyendo la creación automática y persistente de la red virtual requerida, así como el despliegue del **backend Flask del Dashboard UMA**.

---

## ⚙️ 0. Introducción

El script principal `openstack-installer.sh` ejecuta **todo el proceso de despliegue**:

- Instalación de dependencias del sistema y Python.  
- Configuración de Docker y Terraform.  
- Creación del entorno virtual (`openstack_venv`).  
- Instalación de **Kolla-Ansible** y **OpenStackClient**.  
- Creación automática de la topología de red virtual (`uplinkbridge`, `veth0`, `veth1`) con persistencia mediante **systemd**.  
- Despliegue completo de OpenStack.  
- Generación de credenciales (`admin-openrc.sh`, `clouds.yaml`).

---

## 🧠 1. Red Virtual Interna Persistente (Auto-Creada)

Durante la instalación, el script configura automáticamente una red virtual que OpenStack usa como:

- **Red de gestión (Management network)** → interfaz principal (por ejemplo, `ens33`).  
- **Red externa (Neutron external network)** → interfaz virtual `veth1`, conectada al puente `uplinkbridge`.

Esta red se conserva tras cada reinicio mediante el servicio **systemd** `setup-veth.service`, generado automáticamente por el instalador.

### 📡 Topología Creada

                ┌────────────┐          ┌──────────────┐
                │   ens33    │◀────────▶│   Internet   │
                └────────────┘          └──────────────┘
                        │
                  [ NAT / iptables ]
                        │
                ┌──────────────────────┐
                │     uplinkbridge     │
                └──────────────────────┘
                        │
                   ┌────┴────┐
                   │         │
              ┌────────┐ ┌────────┐
              │ veth0  │ │ veth1  │
              └────────┘ └────────┘

🔁 Si el sistema se reinicia, `systemd` ejecuta automáticamente `setup-veth.sh`, garantizando que la red siga activa.

---

## ⚙️ 2. Instalación de OpenStack

Con el entorno virtual configurado y la red virtual activa, simplemente ejecuta:

```bash
sudo bash openstack-installer.sh 2>&1 | tee nombre_del_log.log


## 📂 Ubicación y Flujo de Instalación

El archivo **`openstack-installer.sh`** se encuentra en el directorio:

## 📂 Ubicación y Flujo de Instalación

El archivo **`openstack-installer.sh`** se encuentra en el directorio:

openstack-installer/


Durante la instalación, el script ejecuta automáticamente los siguientes pasos:

1. 🧱 **Crea la red virtual persistente.**  
2. 🐳 **Instala Docker, Ansible, Kolla-Ansible y Terraform.**  
3. ⚙️ **Inicializa los contenedores de OpenStack.**  
4. 🚫 **Desactiva servicios opcionales** (`masakari`, `venus`, `skyline`).  
5. 📁 **Copia el inventario** en:  


/etc/kolla/ansible/inventory/all-in-one

6. 🧩 **Ejecuta**:


kolla-ansible post-deploy

para generar credenciales y archivos de configuración finales.

---

## 🔐 3. Credenciales de Acceso

Una vez completada la instalación, se generan automáticamente los siguientes archivos:



/etc/kolla/admin-openrc.sh
/etc/kolla/clouds.yaml


Carga las credenciales de administrador con:

```bash
source /etc/kolla/admin-openrc.sh


Desde el Dashboard de OpenStack (Horizon) puedes generar Application Credentials y descargarlas como archivo .sh para autenticación persistente:

source app-cred-admin-openrc.sh

🧾 4. Verificación del Entorno

Comprueba el estado de los servicios y recursos básicos:

  openstack service list
  openstack network list
  openstack image list
  openstack flavor list


✅ Si estos comandos devuelven resultados válidos, el despliegue está operativo.

Verifica también los contenedores activos:

sudo docker ps --format "table {{.Names}}\t{{.Status}}"

🧱 5. Creación de Infraestructura Inicial (Terraform)

Una vez desplegado OpenStack, accede al directorio initial para generar los recursos base del entorno UMA:

  cd initial
  source menu-initial.sh
  source ejecutar_terraform_inicial.sh



Estos scripts crean automáticamente redes, imágenes, sabores y claves SSH utilizando Terraform.

💻 6. Lanzamiento del Backend del Dashboard UMA

El backend está implementado en Flask + Gunicorn.
Puedes lanzarlo de dos maneras:

🟢 Opción 1 — Ejecución Directa
  gunicorn -w 4 -b localhost:5001 app:app

🟢 Opción 2 — Ejecución Recomendada

Usa el script start_dashboard.sh, que valida el puerto, instala Gunicorn si falta y lanza el servidor automáticamente:

chmod +x start_dashboard.sh
(openstack_venv)$ bash start_dashboard.sh 2>&1 | tee dashboard_log.log

🌐 7. Acceso al Dashboard UMA

Una vez iniciado el backend, abre en tu navegador:

  👉 http://localhost:5001