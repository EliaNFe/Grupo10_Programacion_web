.PHONY: run test generate

# Levanta todo (DB, sqlc, templ, servidor) y prueba la página y el formulario

# Genera el código de sqlc y de templ
generate:
	sqlc generate
	templ generate

.PHONY: db-up db-down server-up server-down up down

db-up:
	bash ./start-db.sh

db-down:
	bash ./stop-db.sh

server-up:
	bash ./start-server.sh

server-down:
	bash ./stop-server.sh

# Todo junto: base + servidor
up: db-up server-up

# Todo junto: servidor + base
down: server-down db-down
