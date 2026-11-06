#!/usr/bin/env bash
# Compila e inicia el servidor Go en segundo plano.
# Si ya había uno iniciado con este script, lo reinicia (útil tras cambiar código).
# Log: .run/server.log   |   PID: .run/server.pid
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if command -v go >/dev/null 2>&1; then
    export PATH="$PATH:$(go env GOPATH)/bin"
fi
for cmd in go sqlc templ curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Falta '$cmd'. Corré ./dependencias.sh"; exit 1; }
done
[[ -f .env ]] || { echo "No existe el archivo .env"; exit 1; }
set -a; source .env; set +a

BASE="http://localhost:${SERVER_PORT:-8080}"
RUN_DIR=".run"
PID_FILE="$RUN_DIR/server.pid"
LOG_FILE="$RUN_DIR/server.log"
BIN="$RUN_DIR/server"
mkdir -p "$RUN_DIR"

if [[ -f "$PID_FILE" ]]; then
    echo "Ya había un servidor iniciado, reiniciando..."
    bash ./stop-server.sh
fi

if curl -s -o /dev/null "$BASE/"; then
    echo "ERROR: el puerto ${SERVER_PORT:-8080} ya está ocupado por otro proceso."
    echo "Ver cuál es:  lsof -i :${SERVER_PORT:-8080}"
    exit 1
fi

echo "Generando código sqlc..."
sqlc generate || exit 1

echo "Generando código templ..."
templ generate || exit 1

echo "Compilando..."
go build -o "$BIN" . || exit 1

echo "Iniciando servidor..."
nohup "$BIN" >"$LOG_FILE" 2>&1 </dev/null &
echo $! > "$PID_FILE"
PID=$(cat "$PID_FILE")

for _ in $(seq 1 15); do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "ERROR: el servidor se cayó al arrancar. ¿Está levantada la base? (./start-db.sh)"
        echo "--- log ---"
        cat "$LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
    curl -s -o /dev/null "$BASE/" && break
    sleep 1
done

if curl -s -o /dev/null "$BASE/"; then
    echo "Servidor listo en $BASE (PID $PID)"
    echo "Ver logs en vivo:  tail -f $LOG_FILE"
else
    echo "ERROR: el servidor no respondió a tiempo. Revisá $LOG_FILE"
    exit 1
fi
