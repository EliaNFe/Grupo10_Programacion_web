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

	// Conexión a la base (los datos vienen de la configuración)
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

	queries := dbsqlc.New(conn)                      // repository
	movieService := service.NewMovieService(queries) // service
	h := handler.New(movieService)                   // controller

	// Archivos estáticos
	fs := http.FileServer(http.Dir("static"))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	// Home
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			w.WriteHeader(http.StatusNotFound)
			http.ServeFile(w, r, "handler/error.html")
			return
		}
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			http.ServeFile(w, r, "handler/error_method.html")
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		http.ServeFile(w, r, "static/index.html")
	})

	// CRUD de películas
	http.HandleFunc("POST /movies", h.CreateMovie)
	http.HandleFunc("GET /movies", h.ListMovies)
	http.HandleFunc("GET /movies/{id}", h.GetMovie)
	http.HandleFunc("PUT /movies/{id}", h.UpdateMovie)
	http.HandleFunc("DELETE /movies/{id}", h.DeleteMovie)

	fmt.Printf("servidor escuchando en http://localhost%s\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Error al iniciar el servidor: %s\n", err)
	}
}
