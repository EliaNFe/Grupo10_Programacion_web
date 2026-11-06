#!/usr/bin/env bash
# Detiene PostgreSQL y borra los datos (volumen).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

docker compose down -v && echo "PostgreSQL detenido y datos borrados."
