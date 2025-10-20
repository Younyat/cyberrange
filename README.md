# 🧩 Guía de Despliegue de OpenStack y Dashboard UMA

Este documento describe los pasos necesarios para **instalar OpenStack**, **configurar sus credenciales**, **crear la infraestructura inicial** (imágenes, redes, sabores, claves) y finalmente **lanzar el backend del Dashboard UMA**, basado en **Flask y Gunicorn**.

---

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


