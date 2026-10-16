#!/usr/bin/env bash
cleanup() {
    echo "=== Limpiando contenedores y volúmenes ==="
    docker compose down -v
}

trap cleanup EXIT

echo "=== Abriendo contenedores ==="
docker compose up -d
echo "=== Esperando PostgreSQL ==="
until docker exec movies_postgres pg_isready -U postgres -d moviesdb >/dev/null 2>&1
do
    sleep 1
done
echo "=== Contenedores listos ==="


BASE="http://localhost:8080"

# Muestra el body y, en la línea siguiente, el código HTTP
CURL="curl -s -w \n[HTTP_%{http_code}]\n"

echo "=== 1. CREATE (película 1) ==="
$CURL -X POST $BASE/movies -H "Content-Type: application/json" \
  -d '{"title":"Interstellar","description":"Ciencia ficción","release_date":"2014-11-07","duration":169}'

echo "=== 2. CREATE (película 2) ==="
$CURL -X POST $BASE/movies -H "Content-Type: application/json" \
  -d '{"title":"Inception","description":"Sueños dentro de sueños","release_date":"2010-07-16","duration":148}'

echo "=== 3. CREATE (película 3) ==="
$CURL -X POST $BASE/movies -H "Content-Type: application/json" \
  -d '{"title":"The Matrix","description":"Realidad simulada","release_date":"1999-03-31","duration":136}'

echo "=== 4. GET todas ==="
$CURL $BASE/movies

echo "=== 5. GET id 2 ==="
$CURL $BASE/movies/2

echo "=== 6. UPDATE id 1 ==="
$CURL -X PUT $BASE/movies/1 -H "Content-Type: application/json" \
  -d '{"title":"Interstellar (editada)","description":"Descripción nueva","release_date":"2014-11-07","duration":170}'

echo "=== 7. GET id 1 (debe verse editada) ==="
$CURL $BASE/movies/1

echo "=== 8. DELETE id 2 ==="
$CURL -X DELETE $BASE/movies/2

echo "=== 9. GET todas (debe faltar la 2) ==="
$CURL $BASE/movies
