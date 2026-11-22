-include .env
export
export PATH := $(PATH):$(shell go env GOPATH)/bin

SERVER_PORT ?= 8080
BASE_URL := http://localhost:$(SERVER_PORT)
RUN_DIR := .run
BIN := $(RUN_DIR)/server
PID_FILE := $(RUN_DIR)/server.pid
LOG_FILE := $(RUN_DIR)/server.log

.PHONY: sqlc templ generate build db-up db-down server-up server-down up down test run

# Reglas atómicas de generación de código
sqlc:
	sqlc generate

templ:
	templ generate

# Compone las reglas de generación de código
generate: sqlc templ

# Compila el binario después de generar el código de sqlc y templ
build: generate
	@mkdir -p $(RUN_DIR)
	go build -o $(BIN) .

# Levanta PostgreSQL en Docker y espera a que acepte conexiones
db-up:
	docker compose down -v
	docker compose up -d
	@echo "Esperando a que PostgreSQL esté listo..."
	@tries=0; \
	until docker exec movies_postgres pg_isready -h 127.0.0.1 -U "$(DB_USER)" -d "$(DB_NAME)" >/dev/null 2>&1; do \
		tries=$$((tries + 1)); \
		if [ $$tries -gt 60 ]; then \
			echo "ERROR: PostgreSQL no quedó listo a tiempo"; \
			docker compose logs --tail 20; \
			exit 1; \
		fi; \
		sleep 1; \
	done
	@echo "PostgreSQL listo."

# Detiene PostgreSQL y elimina volúmenes
db-down:
	docker compose down -v

# Compila (encadenando generate -> build) e inicia el servidor en segundo plano
server-up: build
	@if [ -f "$(PID_FILE)" ]; then $(MAKE) server-down; fi
	@nohup "$(BIN)" >"$(LOG_FILE)" 2>&1 </dev/null & echo $$! > "$(PID_FILE)"
	@PID=$$(cat "$(PID_FILE)"); \
	for _ in $$(seq 1 15); do \
		if ! kill -0 "$$PID" 2>/dev/null; then \
			echo "ERROR: el servidor se cayó al arrancar."; \
			cat "$(LOG_FILE)"; \
			rm -f "$(PID_FILE)"; \
			exit 1; \
		fi; \
		curl -s -o /dev/null "$(BASE_URL)/" && break; \
		sleep 1; \
	done; \
	echo "Servidor listo en $(BASE_URL) (PID $$PID)"

# Detiene el servidor en segundo plano si está corriendo
server-down:
	@if [ -f "$(PID_FILE)" ]; then \
		PID=$$(cat "$(PID_FILE)"); \
		if kill -0 "$$PID" 2>/dev/null; then \
			kill "$$PID" 2>/dev/null || true; \
			echo "Servidor detenido (PID $$PID)."; \
		fi; \
		rm -f "$(PID_FILE)"; \
	else \
		echo "No hay un servidor registrado."; \
	fi

# Todo junto: reutiliza las reglas db-up y server-up
up: db-up server-up

# Todo junto: reutiliza las reglas server-down y db-down
down: server-down db-down

# Reutiliza generate y db-up, ejecuta los tests de Go y apaga la base al terminar
test: generate db-up
	@status=0; \
	go test ./tests/... -v || status=$$?; \
	$(MAKE) db-down; \
	exit $$status

# Reutiliza up, ejecuta las pruebas integrales con curl y apaga todo con down
run: up
	@status=0; \
	bash ./request.sh --no-setup || status=$$?; \
	$(MAKE) down; \
	exit $$status
