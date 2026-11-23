#!/usr/bin/env bash
# Levanta PostgreSQL y el servidor, y verifica con curl la página SSR y el formulario.
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

[[ -f .env ]] || { echo "No existe el archivo .env"; exit 1; }
set -a; source .env; set +a

BASE="http://localhost:${SERVER_PORT:-8080}"
TMP_DIR="$(mktemp -d)"
BODY_FILE="$TMP_DIR/body"
HEADERS_FILE="$TMP_DIR/headers"

cleanup() {
    rm -rf "$TMP_DIR"
    if [[ "${1:-}" != "--no-setup" ]]; then
        echo
        echo "=== Deteniendo servidor y limpiando contenedores/volúmenes ==="
        bash ./stop-server.sh || true
        bash ./stop-db.sh || true
    fi
}

if [[ "${1:-}" == "--no-setup" ]]; then
    trap 'cleanup --no-setup' EXIT
else
    trap cleanup EXIT
    bash ./start-db.sh
    bash ./start-server.sh
fi

FAILS=0
CHECKS=0

pass() {
    CHECKS=$((CHECKS + 1))
    echo "  OK: $1"
}

fail() {
    CHECKS=$((CHECKS + 1))
    FAILS=$((FAILS + 1))
    echo "  FAIL: $1"
}

expect_status() {
    local expected=$1 actual=$2 label=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label (HTTP $actual)"
    else
        fail "$label (esperaba HTTP $expected, obtuvo $actual)"
    fi
}

expect_contains() {
    local needle=$1 label=$2
    if grep -Fq "$needle" "$BODY_FILE"; then
        pass "$label"
    else
        fail "$label (no se encontró '$needle')"
    fi
}

expect_not_contains() {
    local needle=$1 label=$2
    if ! grep -Fq "$needle" "$BODY_FILE"; then
        pass "$label"
    else
        fail "$label (apareció '$needle' y no debía)"
    fi
}

echo
echo "=== 1. GET / inicial (formulario y lista vacía) ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/")
expect_status 200 "$STATUS" "GET / devuelve 200"
expect_contains '<form' "Muestra el formulario"
expect_contains 'hx-post="/movies"' "El formulario incluye hx-post"
expect_contains 'Todavía no hay películas cargadas.' "Muestra mensaje de lista vacía"

echo
echo "=== 2. POST /movies (HTMX) crea película y devuelve el HTML de la lista ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/movies" \
    --data-urlencode "title=Interstellar" \
    --data-urlencode "description=Ciencia ficción" \
    --data-urlencode "release_date=2014-11-07" \
    --data-urlencode "duration=169")
expect_status 200 "$STATUS" "POST /movies devuelve 200 OK"
expect_contains 'id="movie-list"' "Devuelve el contenedor de la lista de películas"
expect_contains 'Interstellar' "El HTML devuelto contiene la nueva película"
expect_contains 'hx-delete=' "Cada elemento contiene el botón con hx-delete"

echo
echo "=== 3. POST /movies con caracteres especiales (escape HTML) ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/movies" \
    --data-urlencode "title=Matrix <script>alert(1)</script>" \
    --data-urlencode "description=Acción & fantasía" \
    --data-urlencode "release_date=1999-03-31" \
    --data-urlencode "duration=136")
expect_status 200 "$STATUS" "POST /movies con caracteres HTML devuelve 200 OK"
expect_contains 'Matrix &lt;script&gt;alert(1)&lt;/script&gt;' "Escapa tags HTML en el título"
expect_contains 'Acción &amp; fantasía' "Escapa ampersand en la descripción"
expect_not_contains '<script>alert(1)</script>' "No inyecta el tag <script> sin escapar"

echo
echo "=== 4. GET / muestra las películas en orden de creación y escapa HTML ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/")
expect_status 200 "$STATUS" "GET / devuelve 200"
expect_not_contains 'Todavía no hay películas cargadas.' "Ya no muestra lista vacía"
expect_contains 'Interstellar' "Muestra la primera película"
expect_contains 'Matrix' "Muestra la segunda película"

BODY_CONTENT=$(cat "$BODY_FILE")
REST="${BODY_CONTENT#*Interstellar}"
if [[ "$BODY_CONTENT" != "$REST" && "$REST" == *Matrix* ]]; then
    pass "Las películas aparecen en orden de creación"
else
    fail "Las películas no están en el orden esperado"
fi

echo
echo "=== 5. EDICIÓN (HTMX): GET edit form, GET cancel y PUT update ==="
# Extraer un ID de película existente de la respuesta anterior
MOVIE_ID=$(grep -o '/movies/[0-9]\+' "$BODY_FILE" | head -n1 | cut -d/ -f3 || echo 1)

# 5.1 Pedir formulario de edición en la fila
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/movies/$MOVIE_ID/edit")
expect_status 200 "$STATUS" "GET /movies/$MOVIE_ID/edit devuelve 200 OK"
expect_contains "hx-put=\"/movies/$MOVIE_ID\"" "El formulario inline contiene hx-put para guardar"
expect_contains "hx-get=\"/movies/$MOVIE_ID\"" "Contiene botón Cancelar con hx-get"
expect_contains 'name="title"' "Contiene input title"

# 5.2 Cancelar edición (pide la fila normal de nuevo)
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/movies/$MOVIE_ID")
expect_status 200 "$STATUS" "GET /movies/$MOVIE_ID (cancelar) devuelve 200 OK"
expect_contains "hx-get=\"/movies/$MOVIE_ID/edit\"" "Vuelve a mostrar la fila normal con botón Editar"
expect_not_contains "hx-put" "Ya no contiene inputs de edición"

# 5.3 Modificar película con PUT
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PUT "$BASE/movies/$MOVIE_ID" \
    --data-urlencode "title=Interstellar IMAX" \
    --data-urlencode "description=Ciencia ficción mejorada" \
    --data-urlencode "release_date=2014-11-07" \
    --data-urlencode "duration=175")
expect_status 200 "$STATUS" "PUT /movies/$MOVIE_ID devuelve 200 OK"
expect_contains "Interstellar IMAX" "La fila actualizada contiene el nuevo título"
expect_contains "Ciencia ficción mejorada" "La fila actualizada contiene la nueva descripción"
expect_contains "175 min" "La fila actualizada contiene la nueva duración"

# 5.4 PUT con datos inválidos devuelve 400
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PUT "$BASE/movies/$MOVIE_ID" \
    --data-urlencode "title=   " \
    --data-urlencode "description=Inválido" \
    --data-urlencode "release_date=2014-11-07" \
    --data-urlencode "duration=175")
expect_status 400 "$STATUS" "PUT con título vacío devuelve 400"

echo
echo "=== 6. DELETE /movies/{id} (HTMX) elimina película y devuelve 200 ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X DELETE "$BASE/movies/$MOVIE_ID")
expect_status 200 "$STATUS" "DELETE /movies/$MOVIE_ID devuelve 200 OK"

# Verificar que ya no aparece en GET /
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/")
expect_not_contains "/movies/$MOVIE_ID" "La película borrada ya no figura en la lista"

echo
echo "=== 7. Datos inválidos al crear devuelven 400 y no se guardan ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/movies" \
    --data-urlencode "title=   " \
    --data-urlencode "description=Sin título" \
    --data-urlencode "release_date=2020-01-01" \
    --data-urlencode "duration=100")
expect_status 400 "$STATUS" "Título vacío devuelve 400"

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/movies" \
    --data-urlencode "title=Pelicula invalida" \
    --data-urlencode "description=Fecha mal" \
    --data-urlencode "release_date=31/12/2020" \
    --data-urlencode "duration=100")
expect_status 400 "$STATUS" "Fecha inválida devuelve 400"

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST "$BASE/movies" \
    --data-urlencode "title=Pelicula invalida" \
    --data-urlencode "description=Duración 0" \
    --data-urlencode "release_date=2020-01-01" \
    --data-urlencode "duration=0")
expect_status 400 "$STATUS" "Duración <= 0 devuelve 400"

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/")
expect_not_contains 'Pelicula invalida' "Los datos inválidos no se guardaron en la base"

echo
echo "=== 8. Rutas y métodos no soportados devuelven 404 y 405 ==="
STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$BASE/ruta-inexistente")
expect_status 404 "$STATUS" "Ruta inexistente devuelve 404"

STATUS=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PUT "$BASE/")
expect_status 405 "$STATUS" "Método no permitido en / devuelve 405"

echo
if [[ "$FAILS" -eq 0 ]]; then
    echo "=== OK: $CHECKS verificaciones pasaron ==="
else
    echo "=== FALLARON $FAILS de $CHECKS verificaciones ==="
    exit 1
fi
