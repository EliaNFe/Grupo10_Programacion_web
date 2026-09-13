#!/usr/bin/env bash

set -euo pipefail

# Siempre trabajar desde la carpeta donde está este script
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

echo "======================================"
echo " Verificando dependencias"
echo "======================================"

# -------------------------
# GO
# -------------------------

if ! command -v go >/dev/null 2>&1; then
    echo "Go no está instalado. Instalando..."
    sudo apt update
    sudo apt install -y golang-go
else
    echo "✓ Go instalado: $(go version)"
fi

# -------------------------
# DOCKER
# -------------------------

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker no está instalado. Instalando..."

    sudo apt update
    sudo apt install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update

    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    sudo usermod -aG docker "$USER"

    echo
    echo "Docker fue instalado."
    echo "IMPORTANTE: puede ser necesario cerrar sesión y volver a entrar"
    echo "para poder usar Docker sin sudo."
    exit 0
else
    echo "✓ Docker instalado: $(docker --version)"
fi

# -------------------------
# DOCKER COMPOSE
# -------------------------

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose no está instalado. Instalando..."

    sudo apt update
    sudo apt install -y docker-compose-plugin
else
    echo "✓ Docker Compose instalado: $(docker compose version)"
fi

# -------------------------
# SQLC
# -------------------------

# Agregamos temporalmente GOPATH/bin al PATH
export PATH="$PATH:$(go env GOPATH)/bin"

if ! command -v sqlc >/dev/null 2>&1; then
    echo "sqlc no está instalado. Instalando..."

    go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
else
    echo "✓ sqlc instalado: $(sqlc version)"
fi

# -------------------------
# DEPENDENCIAS DE GO
# -------------------------

echo
echo "=== Descargando dependencias de Go ==="

go mod download
go mod tidy

# -------------------------
# LIMPIEZA AUTOMÁTICA
# -------------------------

cleanup() {
    echo
    echo "=== Limpiando Docker ==="
    docker compose down -v >/dev/null 2>&1 || true
}

trap cleanup EXIT

# -------------------------
# TEST
# -------------------------

echo
echo "======================================"
echo " Ejecutando proyecto"
echo "======================================"

echo "=== Limpiando entorno anterior ==="
docker compose down -v >/dev/null 2>&1 || true

echo "=== Generando código sqlc ==="
sqlc generate

echo "=== Compilando proyecto ==="
go build ./...

echo "=== Levantando PostgreSQL ==="
docker compose up -d

echo "=== Esperando PostgreSQL ==="

until docker exec movies_postgres \
    pg_isready -U postgres -d moviesdb >/dev/null 2>&1
do
    sleep 1
done

echo "✓ PostgreSQL listo"

echo
echo "=== Ejecutando tests ==="

go test ./... -v

echo
echo "======================================"
echo " TODO OK"
echo "======================================"
