import json
import subprocess
from flask import Flask, request, jsonify, send_from_directory  # <-- CORRECCIÓN
from flask_cors import CORS
import logging
import os
from logging.handlers import RotatingFileHandler
import sys
import re

# ===== Configurar logging =====
log_file = 'app.log'
logger = logging.getLogger('app_logger')
logger.setLevel(logging.INFO)

handler = RotatingFileHandler(log_file, maxBytes=5*1024*1024, backupCount=3)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

class StreamToLogger(object):
    def __init__(self, logger, level):
        self.logger = logger
        self.level = level
    def write(self, message):
        if message.rstrip() != "":
            self.logger.log(self.level, message.rstrip())
    def flush(self):
        pass

logging.basicConfig(level=logging.INFO)
sys.stdout = StreamToLogger(logger, logging.INFO)
sys.stderr = StreamToLogger(logger, logging.ERROR)

app = Flask(__name__)
CORS(app)

# === Cargar credenciales OpenStack ===
OPENRC_PATH = os.path.join(os.path.dirname(__file__), "admin-openrc.sh")
if os.path.exists(OPENRC_PATH):
    try:
        with open(OPENRC_PATH) as f:
            for line in f:
                line = line.strip()
                if line.startswith("export "):
                    key, value = line.replace("export ", "").split("=", 1)
                    os.environ[key] = value
        logger.info(f"✅ Credenciales OpenStack cargadas desde {OPENRC_PATH}")
    except Exception as e:
        logger.error(f"⚠️ Error al cargar {OPENRC_PATH}: {e}")
else:
    logger.warning(f"⚠️ Archivo {OPENRC_PATH} no encontrado. Los comandos OpenStack pueden fallar.")

MOCK_SCENARIO_DATA = {}
SCENARIO_FILE = "scenario/scenario_file.json"

DEFAULT_SCENARIO = {
    "scenario_name": "Default Empty Scenario",
    "description": "Escenario por defecto: no se encontró 'scenario_file.json'",
    "nodes": [{"data": {"id": "n1", "name": "Nodo Inicial"}, "position": {"x": 100, "y": 100}}],
    "edges": []
}

try:
    with open(SCENARIO_FILE, 'r') as f:
        MOCK_SCENARIO_DATA["file"] = json.load(f)
except Exception:
    MOCK_SCENARIO_DATA["file"] = DEFAULT_SCENARIO

# === Rutas API ===
@app.route('/api/console_url', methods=['POST'])
def get_console_url():
    data = request.get_json()
    instance_name = data.get('instance_name')
    logging.info(f"Consultar terminal del nodo {instance_name}")
    if not instance_name:
        return jsonify({'error': "Falta 'instance_name'"}), 400

    script_path = os.path.join(os.path.dirname(__file__), "scenario/get_console_url.sh")
    if not os.path.isfile(script_path):
        return jsonify({'error': f"Script no encontrado: {script_path}"}), 500

    try:
        proc = subprocess.run(
            [script_path, instance_name],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False
        )
        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        app.logger.info(f"script stdout: {stdout}")
        app.logger.info(f"script stderr: {stderr}")

        text_to_search = stdout + "\n" + stderr
        m = re.search(r'https?://[^\s\'"<>]+', text_to_search)
        if not m:
            logging.info(f"No se encontró URL de la instancia'{instance_name}")
            return jsonify({'error': 'No se encontró URL de la instancia', 'stdout': stdout, 'stderr': stderr}), 500
        url = m.group(0)

        return jsonify({'message': f'Consola solicitada para {instance_name}', 'output': url})
    except Exception as e:
        logging.info(f"Error ejecutando script'{instance_name}")
        app.logger.exception("Error ejecutando script")
        return jsonify({'error': 'Error interno', 'details': str(e)}), 500

@app.route('/api/get_scenario/<scenarioName>', methods=['GET'])
def get_scenario(scenarioName):
    try:
        with open(SCENARIO_FILE, 'r') as f:
            scenario = json.load(f)
        return jsonify(scenario), 200
    except FileNotFoundError:   
        return jsonify({"status": "error", "message": "Archivo no encontrado"}), 404
    except json.JSONDecodeError:
        return jsonify({"status": "error", "message": "JSON inválido"}), 500

@app.route('/api/create_scenario', methods=['POST'])
def create_scenario():
    try:
        scenario_data = request.get_json()
        if not scenario_data:
            return jsonify({"status": "error", "message": "No se recibió JSON válido"}), 400

        scenario_name = scenario_data.get('scenario_name', 'Escenario_sin_nombre')
        safe_name = scenario_name.replace(' ', '_').replace(':', '').replace('/', '_').replace('\\', '_')
        file_path = f"scenario_{safe_name}.json"

        # Guardar el escenario recibido
        with open(file_path, 'w') as f:
            json.dump(scenario_data, f, indent=4)
        logging.info(f"📄 Escenario guardado en {file_path}")

        # Directorio de salida
        outdir = "./tf_out"
        os.makedirs(outdir, exist_ok=True)

        script_path = os.path.join(os.path.dirname(__file__), "scenario/generate_terraform.sh")
        if not os.path.exists(script_path):
            return jsonify({"status": "error", "message": f"Script no encontrado: {script_path}"}), 500

        # --- Crear archivo de estado ---
        status_file = "scenario/deployment_status.json"
        with open(status_file, "w") as sfile:
            json.dump({
                "status": "running",
                "message": f"⏳ Despliegue en curso para '{scenario_name}'. Esto puede tardar varios minutos...",
                "pid": None
            }, sfile, indent=4)

        # --- Lanzar el script de forma asíncrona ---
        process = subprocess.Popen(
            ["bash", script_path, file_path, outdir],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        logging.info(f"🚀 Despliegue iniciado en background (PID={process.pid}) para {scenario_name}")

        # --- Guardar PID y estado inicial ---
        with open("last_deployment.pid", "w") as pidfile:
            pidfile.write(str(process.pid))
        with open(status_file, "w") as sfile:
            json.dump({
                "status": "running",
                "message": f"🚀 Despliegue iniciado para '{scenario_name}'. Esto puede tardar algunos minutos...",
                "pid": process.pid
            }, sfile, indent=4)


        # --- Crear función de monitoreo ---
        def monitor_process():
            stdout, stderr = process.communicate()
            if process.returncode == 0:
                logging.info(f"✅ Despliegue completado correctamente para '{scenario_name}'")
                with open(status_file, "w") as sfile:
                    json.dump({
                        "status": "success",
                        "message": f"✅ Despliegue completado correctamente para '{scenario_name}'.",
                        "stdout": stdout,
                        "stderr": stderr
                    }, sfile, indent=4)
            else:
                logging.error(f"❌ Error en el despliegue de '{scenario_name}': {stderr}")
                with open(status_file, "w") as sfile:
                    json.dump({
                        "status": "error",
                        "message": f"❌ Error al desplegar '{scenario_name}'",
                        "stdout": stdout,
                        "stderr": stderr
                    }, sfile, indent=4)

        # --- Ejecutar monitor en background ---
        import threading
        threading.Thread(target=monitor_process, daemon=True).start()

        # --- Respuesta inmediata al frontend ---
        return jsonify({
            "status": "running",
            "message": f"🚀 Despliegue de '{scenario_name}' iniciado. Esto puede tardar algunos minutos...",
            "pid": process.pid,
            "file": file_path,
            "output_dir": outdir
        }), 202

    except Exception as e:
        logging.error(f"❌ Error al procesar escenario: {e}")
        return jsonify({"status": "error", "message": f"Error interno: {str(e)}"}), 500

# === NUEVA RUTA: ESTADO DE DESPLIEGUE ===
@app.route('/api/deployment_status', methods=['GET'])
def deployment_status():
    """Devuelve el estado actual del despliegue leído desde deployment_status.json"""
    status_file = "scenario/deployment_status.json"

    if not os.path.exists(status_file):
        return jsonify({
            "status": "unknown",
            "message": "⚠️ No existe archivo de estado de despliegue."
        }), 404

    try:
        with open(status_file, "r") as sfile:
            data = json.load(sfile)
        return jsonify(data), 200
    except json.JSONDecodeError:
        return jsonify({
            "status": "error",
            "message": "⚠️ Error al leer JSON de estado."
        }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": f"⚠️ Error interno: {str(e)}"
        }), 500

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('static', path)

if __name__ == "__main__":
    app.run(host="localhost", port=5001, debug=True)
