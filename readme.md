# Catálogo de películas

Proyecto de un catálogo para agregar, editar, borrar y listar películas con su descripción, título, año de lanzamiento, clasificación, género, duración y directores.

Actualmente el servidor muestra una página de presentación. El esquema y las consultas SQL están preparados, pero el servidor todavía no se conecta a PostgreSQL ni expone operaciones CRUD.

## Flujo de peticiones

Cliente
  │  POST /movies  {"title":"Interstellar", ...}
  ▼
main.go            → elige qué handler atiende "POST /movies"
  ▼
handler            → lee el JSON, lo convierte, llama al service
  ▼
service            → valida las reglas y llama al repository
  ▼
Queries (sqlc)     → ejecuta el INSERT en Postgres
  ▼
vuelve todo hacia arriba hasta que el handler escribe la respuesta 201

  ## Verificar dependencias
Correr el script dependencias.sh para verificar versiones o aplicaciones instaladas para correr la web. (GO, Docker, sqlc)

  ## Arrancar el servidor  

Desde la carpeta del proyecto, con Go 1.22.2 o superior:
Nosotros dejamos el archivo .env en el repo por cuestiones practicas no es una practica bueno hacer eso :) 

```bash
set -a; source .env; set +a  (no olvidarse de tener el .env con las credenciales)
go run .
```

Abrí http://localhost:8080. Para detener el servidor, presioná `Ctrl + C`.
Las páginas HTML se incluyen en el binario al compilar.

## Persistencia

Para levantar PostgreSQL con Docker Compose:

```bash
docker compose up -d
```

La base local usa el puerto 5432, la base `moviesdb` y el usuario y contraseña `postgres`.
El esquema `db/schema/movie.sql` se carga al inicializar un volumen vacío. Cambiar ese archivo no modifica una base ya inicializada.

Las consultas están en `db/queries/queries.sql` y el código generado en `db/sqlc/`.
Después de cambiar el esquema o las consultas, regenerá el código con sqlc:

```bash
sqlc generate
```

Para detener PostgreSQL conservando los datos:

```bash
docker compose down
```

## Tests
Verificación de UnitTest 

```bash
./test.sh
```

El script compila el proyecto y ejecuta los tests HTTP con `go test ./... -v`.
No requiere Docker ni sqlc y no modifica los datos de PostgreSQL.
También podés ejecutar directamente `go test ./...`.

  Verificación de Request
Para verificar GET, POST, PUT y DELETE ejecutar el script request.sh 
```bash
./request.sh
```