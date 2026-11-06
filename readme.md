# Catálogo de películas

Aplicación web para agregar y listar películas (título, descripción, fecha de estreno y duración).
El HTML se genera en el servidor Go con [templ](https://templ.guide) y se estiliza con Pico.css. No hay API JSON ni JavaScript en el cliente: cada acción recarga la página completa.

## Flujo de peticiones

Listar (GET /):

```
Navegador  →  GET /
main.go    →  queries.ListMovies (sqlc) trae las películas de PostgreSQL
views      →  IndexPage(movies) arma la página con Layout + MovieForm + MovieList
main.go    →  escribe el HTML en la respuesta
```

Crear (patrón Post/Redirect/Get):

```
Navegador  →  POST /movies  (formulario: title, description, release_date, duration)
main.go    →  parsea y valida el formulario, queries.CreateMovie (sqlc) hace el INSERT
main.go    →  303 See Other con Location: /
Navegador  →  GET /   (muestra la lista actualizada)
```

## Estructura

- `main.go`: servidor, handler de `GET /` y de `POST /movies`.
- `views/`: componentes templ (`layout.templ`, `entity_form.templ`, `entity_list.templ`, `index_page.templ`).
- `db/schema` y `db/queries`: esquema y consultas SQL; `db/sqlc` es el código que genera sqlc.
- `config/`: lectura de variables de entorno.
- `exceptions/`: páginas HTML de error 404 y 405.

## Dependencias

Correr `./dependencias.sh` para verificar o instalar Go, Docker, sqlc y templ (v0.2.793).

## Generar código

El código de `db/sqlc/` y los archivos `views/*_templ.go` se generan y no se suben al repo:

```bash
make generate
```

(equivale a `sqlc generate` y `templ generate`). Hay que volver a correrlo cada vez que se cambia un `.templ`, el esquema o las consultas.

## Arrancar con make

```bash
make up      # PostgreSQL (Docker) + generación de código + servidor en segundo plano
make down    # detiene el servidor y PostgreSQL
```

También se pueden usar por separado `make db-up`, `make db-down`, `make server-up` y `make server-down`.
Abrí http://localhost:8080. Los logs del servidor quedan en `.run/server.log`.

Nosotros dejamos el archivo .env en el repo por cuestiones practicas, no es una buena practica hacer eso :)

## Arrancar a mano

```bash
docker compose up -d
make generate
set -a; source .env; set +a  # (no olvidarse de tener el .env con las credenciales)
go run .
```

Para detener el servidor, presioná `Ctrl + C`.

## Persistencia

La base local usa el puerto 5432, la base `moviesdb` y el usuario y contraseña `postgres`.
El esquema `db/schema/movie.sql` se carga al inicializar un volumen vacío. Cambiar ese archivo no modifica una base ya inicializada.

Para detener PostgreSQL conservando los datos: `make db-down`. Para borrar también los datos: `./stop-db.sh --clean`.

## Tests

```bash
make test
```

Genera el código, compila el proyecto y ejecuta los tests de las consultas sqlc contra PostgreSQL (`go test ./tests/... -v`). Levanta un PostgreSQL con Docker y lo borra al terminar.

## Prueba de la página y el formulario

```bash
make run
```

Levanta PostgreSQL, genera el código, compila y arranca el servidor, y verifica con `curl` que:

- `GET /` muestra el formulario y la lista (vacía y con películas, en orden de creación).
- `POST /movies` guarda la película y redirige con 303 a `/`.
- El HTML escapa el contenido ingresado.
- Los datos inválidos devuelven 400 y no se guardan.
- Las rutas y métodos no soportados devuelven 404 y 405.

Al terminar detiene el servidor y borra los contenedores y volúmenes.
