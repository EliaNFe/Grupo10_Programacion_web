#!/usr/bin/env bash
# Detiene el servidor iniciado con start-server.sh
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

PID_FILE=".run/server.pid"

if [[ ! -f "$PID_FILE" ]]; then
    echo "No hay un servidor registrado (no existe $PID_FILE)."
    if [[ -f .env ]]; then
        set -a; source .env; set +a
        if command -v lsof >/dev/null 2>&1 && lsof -i ":${SERVER_PORT:-8080}" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "Pero el puerto ${SERVER_PORT:-8080} está ocupado por otro proceso:"
            lsof -i ":${SERVER_PORT:-8080}" -sTCP:LISTEN
        fi
    fi
    exit 0
fi

PID=$(cat "$PID_FILE")

# Se verifica el nombre del proceso para no matar otro que reutilizó el mismo PID
if kill -0 "$PID" 2>/dev/null && [[ "$(ps -p "$PID" -o comm= 2>/dev/null)" == "server" ]]; then
    kill "$PID"
    for _ in $(seq 1 10); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.5
    done
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID"
    fi
    echo "Servidor detenido (PID $PID)."
else
    echo "El servidor ya no estaba corriendo."
fi

rm -f "$PID_FILE"
