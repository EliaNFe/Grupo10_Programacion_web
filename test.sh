#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if command -v go >/dev/null 2>&1; then
    export PATH="$PATH:$(go env GOPATH)/bin"
fi

cleanup() {
    echo "=== Limpiando contenedores y volúmenes ==="
    bash ./stop-db.sh
}

trap cleanup EXIT

echo "=== Generando código sqlc y templ ==="
sqlc generate
templ generate

echo "=== Compilando proyecto ==="
go build ./...

echo "=== Levantando PostgreSQL ==="
bash ./start-db.sh

echo "=== Ejecutando tests ==="
go test ./tests/... -v

echo "=== Todo OK ==="
