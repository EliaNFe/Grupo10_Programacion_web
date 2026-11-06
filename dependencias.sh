#!/usr/bin/env bash

set -euo pipefail

echo "=== Verificando dependencias ==="

# GO
if ! command -v go >/dev/null 2>&1; then
    echo "Go no está instalado. Instalando..."
    sudo apt update
    sudo apt install -y golang-go
else
    echo "✓ Go instalado"
fi

# DOCKER
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
    echo "Docker instalado."
    echo "Cerrá sesión y volvé a entrar para usar Docker sin sudo."
else
    echo "✓ Docker instalado"
fi

# DOCKER COMPOSE
if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose no está instalado. Instalando..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
else
    echo "✓ Docker Compose instalado"
fi

# SQLC
export PATH="$PATH:$(go env GOPATH)/bin"

if ! command -v sqlc >/dev/null 2>&1; then
    echo "sqlc no está instalado. Instalando..."
    go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
else
    echo "✓ sqlc instalado"
fi

# TEMPL
TEMPL_VERSION="v0.2.793"

if ! command -v templ >/dev/null 2>&1 || [[ "$(templ version 2>/dev/null)" != "$TEMPL_VERSION" ]]; then
    echo "templ $TEMPL_VERSION no está instalado. Instalando..."
    go install "github.com/a-h/templ/cmd/templ@$TEMPL_VERSION"
else
    echo "✓ templ $TEMPL_VERSION instalado"
fi

# El código generado no se sube al repo

echo "=== Generando código (sqlc y templ) ==="

sqlc generate
templ generate

echo "=== Dependencias de Go ==="

go mod download
go mod tidy

echo
echo "=== Dependencias listas ==="
