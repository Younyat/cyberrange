# 🧩 Guía de Despliegue de OpenStack y Dashboard UMA

Este documento describe los pasos necesarios para **instalar OpenStack**, **configurar sus credenciales**, **crear la infraestructura inicial** (imágenes, redes, sabores, claves) y finalmente **lanzar el backend del Dashboard UMA**, basado en **Flask y Gunicorn**.

---

## ⚙️ Pre-Openstack-installer

# Crear una topología de red interna virtual
sudo chmod +x setup-veth.sh
sudo bash setup-veth.sh
```
#!/bin/bash
set -euo pipefail

BRIDGE="uplinkbridge"
VETH0="veth0"
VETH1="veth1"
SUBNET="10.0.2.0/24"
GATEWAY="10.0.2.1"
EXT_IF="ens33"

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
```


---------->                  Topología interna creada(Visual)


                                      ┌────────────┐          ┌──────────────┐
                                      │  ens33     │◀────────▶│   Internet   │
                                      └────────────┘          └──────────────┘
                                              │
                                        [ NAT / iptables ]
                                              │
                                      ┌──────────────────────┐
                                      │     uplinkbridge     │  ← puente (bridge)
                                      └──────────────────────┘
                                              │
                                          ┌────┴─────┐
                                          │          │
                                      ┌───────┐  ┌───────┐
                                      │ veth0 │  │ veth1 │  ← par de interfaces virtuales conectadas entre sí
                                      └───────┘  └───────┘



## ⚙️ ¿Por qué es importante para Kolla-Ansible?

OpenStack necesita dos tipos de redes en un despliegue all-in-one:

Gestión interna (Management network)
> se usa ens33 para acceder a los contenedores y servicios internos.

Red externa (Neutron external network)
> requiere una interfaz física o virtual sin dirección IP (como veth1)
para crear Floating IPs y tráfico hacia el exterior.

eEecutar el escipt setup-veth.sh  creará esa interfaz virtual (veth1) conectada a un bridge (uplinkbridge) que tiene salida a Internet mediante NAT.



## ⚙️ Persistencia y recomendaciones

⚠️ Este script crea interfaces temporales:
si reinicias tu máquina, desaparecerán (uplinkbridge, veth0, veth1).

→ Si quieres que se creen automáticamente al iniciar el sistema, puedes:

  > Guardarlo como /usr/local/bin/setup-veth.sh

  > Añadirlo a /etc/rc.local o un servicio systemd que se ejecute al arranque.




## ⚙️ 1. Instalación de OpenStack

Con el entorno virtual activado y las credenciales cargadas :

```bash
source /home/<usuario>/openstack_venv/bin/activate

Comienza ejecutando el script de instalación:

```bash
(openstack_venv)$ source openstack-installer.sh
```

> 📂 Este archivo debe encontrarse dentro del directorio `openstack-installer`.

Una vez completada la instalación, podrás acceder al **Dashboard web de OpenStack** utilizando las credenciales definidas en:

```
/etc/kolla/clouds.yaml
```
###############################################
#  Configuración de Credenciales de OpenStack
# =============================================
# obtenida del archivo `admin-openrc.sh`
# descargado desde el Dashboard de OpenStack.
###############################################

Desde el Dashboard, crea unas **credenciales de aplicación (Application Credentials)** con todos los roles habilitados y sin restricciones.  
Descarga el archivo de credenciales resultante en formato `.sh` y ejecútalo en tu terminal:

```bash
(openstack_venv)$ source admin-openrc.sh
```

---

## 🔐 2. Verificación de Credenciales

Para comprobar que las credenciales se han cargado correctamente, ejecuta:

```bash
(openstack_venv)$ openstack image list
```

Si aparece un error, significa que las variables no se han exportado correctamente.  
En ese caso:

- Ejecuta de nuevo el archivo `.sh`, o  
- Copia manualmente su contenido y pégalo en la terminal para exportar las variables de entorno.

> ✅ Si el comando devuelve la lista de imágenes, las credenciales están configuradas correctamente.

---

## 🧱 3. Creación de la Infraestructura Inicial (Terraform)

En esta etapa se generarán los recursos básicos de OpenStack necesarios para la creación de nodos internos:  
**sabores, imágenes, redes y claves**.

1. Accede al directorio `initial`:
   ```bash
   cd initial
   ```

2. Ejecuta el script:
   ```bash
   (openstack_venv)$ source menu-initial.sh
   ```

   Este script creará automáticamente los archivos de configuración de Terraform (`.tf`) correspondientes a imágenes, sabores, redes y claves.

3. Una vez generados, despliega los recursos en OpenStack:
   ```bash
   (openstack_venv)$ source ejecutar_terraform_inicial.sh
   ```

   Esto aplicará todos los cambios utilizando los comandos de Terraform.

---

## 🔎 4. Verificación de los Recursos Creados

Con el entorno virtual activado y las credenciales cargadas, puedes comprobar que los recursos se han creado correctamente:

(openstack_venv)$ openstack image list
(openstack_venv)$ openstack flavor list
(openstack_venv)$ openstack network list
(openstack_venv)$ openstack keypair list
```

> ✅ Si todos los recursos aparecen en la lista, la configuración inicial de OpenStack está completa.

---

## 💻 5. Lanzamiento del Backend del Dashboard UMA

El backend del Dashboard UMA está basado en **Flask + Gunicorn** y puede ejecutarse de dos formas.

---

### 🟢 OPCIÓN 1 — Lanzamiento directo (sin comprobación de puerto)

En el directorio raíz del proyecto, ejecuta:

```bash
gunicorn -w 4 -b localhost:5001 app:app
```

**Desglose del comando:**

| Parámetro | Descripción |
|------------|-------------|
| `gunicorn` | Servidor WSGI que ejecuta tu aplicación Flask. |
| `-w 4` | Inicia 4 *workers* (procesos paralelos). |
| `-b localhost:5001` | Escucha en el puerto 5001. |
| `app:app` | Indica el módulo y la instancia Flask (`app = Flask(__name__)`). |

> 💡 Esta opción es útil para entornos de desarrollo o pruebas locales.

---

### 🟢 OPCIÓN 2 — Lanzamiento con comprobación del puerto (recomendada)

Para un inicio más seguro y automatizado, utiliza el script **`start_dashboard.sh`**, que realiza comprobaciones previas antes de lanzar Gunicorn.

#### PASO 1 — Asignar permisos de ejecución
```bash
chmod +x start_dashboard.sh
```

#### PASO 2 — Ejecutar el script
```bash
(openstack_venv)$ bash start_dashboard.sh 2>&1 | tee nombre_del_log.log
```

**¿Qué hace este script?**

- Comprueba si el puerto 5001 está en uso.  
  - Si está libre → continúa.  
  - Si está ocupado → ejecuta automáticamente `free_port.sh` para liberarlo.
- Verifica si **Gunicorn** está instalado; si no, lo instala automáticamente.
- Lanza Gunicorn con los parámetros configurados:
  ```bash
  gunicorn -w 4 -b localhost:5001 app:app
  ```
- Muestra mensajes informativos, por ejemplo:
  ```
  ✅ El puerto 5001 está libre.
  🚀 Iniciando servidor Gunicorn (app:app)...
  ```

---

## 🌐 6. Acceso al Dashboard

Una vez iniciado el servidor, el backend del Dashboard estará disponible en:

👉 [http://localhost:5001](http://localhost:5001)

Desde ahí podrás interactuar con la interfaz web del Dashboard y las APIs de Flask para gestionar los **escenarios, redes y nodos** de tu entorno OpenStack.

---


