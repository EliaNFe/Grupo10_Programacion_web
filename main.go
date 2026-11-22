package main

import (
	"database/sql"
	"fmt"
	"net/http"

	_ "github.com/lib/pq"

	"tp/config"
	dbsqlc "tp/db/sqlc"
	"tp/handler"
	"tp/service"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Println("Error de configuración:", err)
		return
	}
	port := ":" + cfg.ServerPort

	// Conexión a la base
	conn, err := sql.Open("postgres", cfg.DatabaseURL())
	if err != nil {
		fmt.Printf("Error al abrir la base: %s\n", err)
		return
	}
	defer conn.Close()

	if err := conn.Ping(); err != nil {
		fmt.Printf("No se pudo conectar a la base: %s\n", err)
		return
	}
	fmt.Println("conexión a la base OK")

	queries := dbsqlc.New(conn)
	movieService := service.NewMovieService(queries)
	movieHandler := handler.New(movieService)

	// Rutas HTTP
	http.HandleFunc("/", movieHandler.IndexPage)
	http.HandleFunc("POST /movies", movieHandler.CreateMovie)
	http.HandleFunc("DELETE /movies/{id}", movieHandler.DeleteMovie)

	fmt.Printf("servidor escuchando en http://localhost%s\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Error al iniciar el servidor: %s\n", err)
	}
}
