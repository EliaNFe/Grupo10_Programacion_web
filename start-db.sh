#!/usr/bin/env bash
# Levanta PostgreSQL con docker compose y espera a que esté listo.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

command -v docker >/dev/null 2>&1 || { echo "Falta 'docker'. Corré ./dependencias.sh"; exit 1; }
[[ -f .env ]] || { echo "No existe el archivo .env"; exit 1; }
set -a; source .env; set +a
echo "Borrando volumenes viejos"
docker compose down -v

echo "Levantando PostgreSQL..."
docker compose up -d || { echo "ERROR: falló docker compose up"; exit 1; }

echo "Esperando a que PostgreSQL esté listo..."
tries=0
# -h 127.0.0.1 fuerza conexión por TCP: el servidor temporal de inicialización
# de la imagen solo escucha por socket, así que esto solo da OK cuando está de verdad listo.
until docker exec movies_postgres pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [[ $tries -gt 60 ]]; then
        echo "ERROR: PostgreSQL no quedó listo a tiempo"
        docker compose logs --tail 20
        exit 1
    fi
    sleep 1
done

echo "PostgreSQL listo."
