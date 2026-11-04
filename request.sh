#!/usr/bin/env bash
# Levanta todo (sqlc, PostgreSQL y servidor) y prueba el CRUD de películas.
# Cada request verifica el código HTTP y algún dato del body.
# Uso: ./request.sh   (termina con código 1 si alguna verificación falla)

set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# ---------- configuración ----------

if [[ ! -f .env ]]; then
    echo "Falta el archivo .env con las credenciales"
    exit 1
fi
set -a; source .env; set +a

export PATH="$PATH:$(go env GOPATH)/bin"
for cmd in go docker sqlc curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Falta $cmd. Ejecutá ./dependencias.sh"
        exit 1
    fi
done

BASE="http://localhost:${SERVER_PORT:-8080}"
TMP_DIR="$(mktemp -d)"
SERVER_BIN="$TMP_DIR/server"
SERVER_LOG="$TMP_DIR/server.log"
BODY_FILE="$TMP_DIR/body"
SERVER_PID=""

cleanup() {
    echo
    echo "=== Deteniendo servidor ==="
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    echo "=== Limpiando contenedores y volúmenes ==="
    docker compose down -v
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

# ---------- preparación ----------

if curl -s -o /dev/null "$BASE/"; then
    echo "Ya hay algo escuchando en $BASE. Detenelo antes de correr este script."
    exit 1
fi

echo "=== Limpiando entorno anterior ==="
docker compose down -v

echo "=== Generando código sqlc ==="
sqlc generate

echo "=== Compilando servidor ==="
go build -o "$SERVER_BIN" .

echo "=== Levantando PostgreSQL ==="
docker compose up -d

echo "=== Esperando PostgreSQL ==="
until docker exec movies_postgres pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
do
    sleep 1
done

echo "=== Levantando servidor en segundo plano ==="
"$SERVER_BIN" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 30); do
    if curl -s -o /dev/null "$BASE/"; then
        break
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "El servidor terminó con error:"
        cat "$SERVER_LOG"
        exit 1
    fi
    sleep 1
done

if ! curl -s -o /dev/null "$BASE/"; then
    echo "El servidor no respondió en $BASE"
    cat "$SERVER_LOG"
    exit 1
fi
echo "=== Servidor listo en $BASE ==="

# ---------- helpers ----------

STATUS=""
BODY=""
FAILS=0
CHECKS=0

# request MÉTODO RUTA [JSON]: deja el código en STATUS y la respuesta en BODY
request() {
    local method=$1 path=$2 data=${3:-}
    local args=(-s -o "$BODY_FILE" -w '%{http_code}' -X "$method" "$BASE$path")
    if [[ -n "$data" ]]; then
        args+=(-H "Content-Type: application/json" -d "$data")
    fi

    STATUS=$(curl "${args[@]}") || STATUS="000"
    BODY=$(cat "$BODY_FILE" 2>/dev/null || true)

    echo "$method $path -> $STATUS"
    if [[ -n "$BODY" ]]; then
        echo "  body: $BODY"
    fi
}

pass() { CHECKS=$((CHECKS + 1)); echo "  ✓ $1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); echo "  ✗ $1"; }

expect_status() {
    if [[ "$STATUS" == "$1" ]]; then
        pass "status $1"
    else
        fail "status esperado $1, recibido $STATUS"
    fi
}

expect_body() {
    if [[ "$BODY" == *"$1"* ]]; then
        pass "body contiene $1"
    else
        fail "body no contiene $1"
    fi
}

expect_body_not() {
    if [[ "$BODY" != *"$1"* ]]; then
        pass "body no contiene $1"
    else
        fail "body no debería contener $1"
    fi
}

expect_empty_body() {
    if [[ -z "$BODY" ]]; then
        pass "body vacío"
    else
        fail "body debería estar vacío"
    fi
}

# Cantidad de películas en la respuesta de GET /movies
expect_count() {
    local count
    count=$(grep -o '"id":' <<<"$BODY" | wc -l | tr -d ' ')
    if [[ "$count" == "$1" ]]; then
        pass "cantidad de películas $1"
    else
        fail "cantidad esperada $1, recibida $count"
    fi
}

# Toma el id del body de un POST
body_id() {
    sed -n 's/.*"id":\([0-9]*\).*/\1/p' <<<"$BODY"
}

# ---------- casos exitosos ----------

echo
echo "=== 1. CREATE (película 1) ==="
request POST /movies '{"title":"Interstellar","description":"Ciencia ficción","release_date":"2014-11-07","duration":169}'
expect_status 201
expect_body '"title":"Interstellar"'
expect_body '"duration":169'
ID1=$(body_id)

echo
echo "=== 2. CREATE (película 2) ==="
request POST /movies '{"title":"Inception","description":"Sueños dentro de sueños","release_date":"2010-07-16","duration":148}'
expect_status 201
expect_body '"title":"Inception"'
ID2=$(body_id)

echo
echo "=== 3. CREATE (película 3) ==="
request POST /movies '{"title":"The Matrix","description":"Realidad simulada","release_date":"1999-03-31","duration":136}'
expect_status 201
expect_body '"release_date":"1999-03-31"'

echo
echo "=== 4. GET todas ==="
request GET /movies
expect_status 200
expect_count 3
expect_body '"title":"The Matrix"'

echo
echo "=== 5. GET id $ID2 ==="
request GET "/movies/$ID2"
expect_status 200
expect_body "\"id\":$ID2"
expect_body '"title":"Inception"'

echo
echo "=== 6. UPDATE id $ID1 ==="
request PUT "/movies/$ID1" '{"title":"Interstellar (editada)","description":"Descripción nueva","release_date":"2014-11-07","duration":170}'
expect_status 200
expect_body '"title":"Interstellar (editada)"'
expect_body '"duration":170'

echo
echo "=== 7. GET id $ID1 (debe verse editada) ==="
request GET "/movies/$ID1"
expect_status 200
expect_body '"title":"Interstellar (editada)"'

echo
echo "=== 8. DELETE id $ID2 ==="
request DELETE "/movies/$ID2"
expect_status 204
expect_empty_body

echo
echo "=== 9. GET id $ID2 (ya borrada) ==="
request GET "/movies/$ID2"
expect_status 404
expect_body '"error":"película no encontrada"'

echo
echo "=== 10. GET todas (debe faltar la $ID2) ==="
request GET /movies
expect_status 200
expect_count 2
expect_body_not '"title":"Inception"'

# ---------- casos de error ----------

echo
echo "=== 11. CREATE con JSON inválido ==="
request POST /movies '{"title":'
expect_status 400
expect_body '"error":"JSON inválido"'

echo
echo "=== 12. CREATE sin título ==="
request POST /movies '{"title":"  ","description":"Sin título","release_date":"2020-01-01","duration":100}'
expect_status 400
expect_body '"error":"el título no puede estar vacío"'

echo
echo "=== 13. CREATE con duración 0 ==="
request POST /movies '{"title":"Corto","description":"Sin duración","release_date":"2020-01-01","duration":0}'
expect_status 400
expect_body '"error":"la duración debe ser mayor a 0"'

echo
echo "=== 14. CREATE con fecha mal formada ==="
request POST /movies '{"title":"Fecha rara","description":"Formato incorrecto","release_date":"07/11/2014","duration":100}'
expect_status 400
expect_body '"error":"release_date debe tener formato YYYY-MM-DD"'

echo
echo "=== 15. GET con id no numérico ==="
request GET /movies/abc
expect_status 400
expect_body '"error":"id inválido"'

echo
echo "=== 16. GET id inexistente ==="
request GET /movies/9999
expect_status 404
expect_body '"error":"película no encontrada"'

echo
echo "=== 17. UPDATE id inexistente ==="
request PUT /movies/9999 '{"title":"No existe","description":"Nada","release_date":"2020-01-01","duration":100}'
expect_status 404
expect_body '"error":"película no encontrada"'

echo
echo "=== 18. GET todas (los errores no crearon películas) ==="
request GET /movies
expect_status 200
expect_count 2

# ---------- resumen ----------

echo
if [[ "$FAILS" -eq 0 ]]; then
    echo "=== OK: $CHECKS verificaciones pasaron ==="
else
    echo "=== FALLARON $FAILS de $CHECKS verificaciones ==="
    exit 1
fi
