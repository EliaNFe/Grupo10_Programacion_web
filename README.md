# Catálogo de películas

Proyecto de un catálogo para agregar, editar, borrar y listar películas con su descripción, título, año de lanzamiento, clasificación, género, duración y directores.

Actualmente el servidor muestra una página de presentación. El esquema y las consultas SQL están preparados, y la parte de persistencia se prueba contra PostgreSQL usando Docker, sqlc y tests en Go.

## Arrancar el servidor

Desde la carpeta del proyecto, con Go 1.22.2 o superior:

```bash
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

Las consultas están en `db/queries/queries.sql` y el código generado por sqlc en `db/sqlc/`.
Después de cambiar el esquema o las consultas, se puede regenerar el código con:

```bash
sqlc generate
```

Para detener PostgreSQL conservando los datos:

```bash
docker compose down
```

## Dependencias

La preparación del entorno está separada de la ejecución de los tests.

El script `dependencias.sh` revisa si están instaladas las herramientas necesarias y, si falta alguna, intenta instalarla. También descarga las dependencias del módulo de Go.

Antes de usarlo por primera vez:

```bash
chmod +x dependencias.sh
./dependencias.sh
```

Este script se usa principalmente al preparar una máquina nueva. No hace falta ejecutarlo cada vez que se corren los tests.

## Tests

Los tests se ejecutan con un script separado:

```bash
chmod +x test.sh
./test.sh
```

`test.sh` se encarga de:

1. Limpiar un entorno anterior de Docker.
2. Ejecutar `sqlc generate`.
3. Compilar el proyecto.
4. Levantar PostgreSQL con Docker Compose.
5. Esperar a que la base esté disponible.
6. Ejecutar los tests con `go test ./... -v`.
7. Bajar el contenedor y eliminar el volumen usado para las pruebas.

De esta forma, `dependencias.sh` queda para preparar el entorno y `test.sh` queda solamente para generar, compilar y probar el proyecto.

Los tests también se pueden ejecutar manualmente con:

```bash
go test ./... -v
```

En ese caso, PostgreSQL debe estar levantado y listo para recibir conexiones.
