#!/usr/bin/env bash

set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

cleanup() {
    echo "=== Limpiando contenedores y volúmenes ==="
    docker compose down -v
}

trap cleanup EXIT

echo "=== Limpiando entorno anterior ==="
docker compose down -v

echo "=== Generando código sqlc ==="
sqlc generate

echo "=== Compilando proyecto ==="
go build ./...

echo "=== Levantando PostgreSQL ==="
docker compose up -d

echo "=== Esperando PostgreSQL ==="
until docker exec movies_postgres pg_isready -U postgres -d moviesdb >/dev/null 2>&1
do
    sleep 1
done

echo "=== Ejecutando tests ==="
go test ./tests/... -v

echo "=== Todo OK ==="
