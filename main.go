package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	_ "github.com/lib/pq"

	"tp/config"
	dbsqlc "tp/db/sqlc"
	"tp/views"
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

	queries := dbsqlc.New(conn) // código generado por sqlc

	// Página principal (cualquier otra ruta o método devuelve su página de error)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			writeErrorPage(w, http.StatusNotFound, "exceptions/error.html")
			return
		}
		if r.Method != http.MethodGet {
			writeErrorPage(w, http.StatusMethodNotAllowed, "exceptions/error_method.html")
			return
		}

		movies, err := queries.ListMovies(r.Context())
		if err != nil {
			fmt.Printf("Error al listar las películas: %s\n", err)
			http.Error(w, "No se pudieron obtener las películas", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := views.IndexPage(movies).Render(r.Context(), w); err != nil {
			fmt.Printf("Error al renderizar la página: %s\n", err)
		}
	})

	// Crear película desde el formulario
	http.HandleFunc("POST /movies", createMovieHandler(queries))

	fmt.Printf("servidor escuchando en http://localhost%s\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Error al iniciar el servidor: %s\n", err)
	}
}

// createMovieHandler atiende POST /movies: lee el formulario, guarda la película
// y redirige a la página principal.
func createMovieHandler(queries *dbsqlc.Queries) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Parsear los datos del formulario
		if err := r.ParseForm(); err != nil {
			http.Error(w, "Formulario inválido", http.StatusBadRequest)
			return
		}

		title := strings.TrimSpace(r.PostFormValue("title"))
		description := strings.TrimSpace(r.PostFormValue("description"))

		// Validaciones (redundancia para mas seguridad)
		if title == "" {
			http.Error(w, "el título no puede estar vacío", http.StatusBadRequest)
			return
		}
		if utf8.RuneCountInString(title) > 255 {
			http.Error(w, "el título no puede superar los 255 caracteres", http.StatusBadRequest)
			return
		}
		if description == "" {
			http.Error(w, "la descripción no puede estar vacía", http.StatusBadRequest)
			return
		}
		if utf8.RuneCountInString(description) > 255 {
			http.Error(w, "la descripción no puede superar los 255 caracteres", http.StatusBadRequest)
			return
		}

		releaseDate, err := time.Parse("2006-01-02", r.PostFormValue("release_date"))
		if err != nil {
			http.Error(w, "la fecha de estreno debe tener formato YYYY-MM-DD", http.StatusBadRequest)
			return
		}

		duration, err := strconv.ParseInt(r.PostFormValue("duration"), 10, 32)
		if err != nil || duration <= 0 {
			http.Error(w, "la duración debe ser un número entero mayor a 0", http.StatusBadRequest)
			return
		}

		// Guardar en la base
		_, err = queries.CreateMovie(r.Context(), dbsqlc.CreateMovieParams{
			Title:       title,
			Description: description,
			ReleaseDate: releaseDate,
			Duration:    int32(duration),
		})
		if err != nil {
			fmt.Printf("Error al guardar la película: %s\n", err)
			http.Error(w, "No se pudo guardar la película", http.StatusInternalServerError)
			return
		}

		//El navegador vuelve a pedir "/" con un GET y ve la lista actualizada
		http.Redirect(w, r, "/", http.StatusSeeOther)
	}
}

// writeErrorPage responde con el código de estado indicado y el HTML de la página de error.
// Se escribe el header una sola vez (http.ServeFile también lo escribe y generaba un aviso en el log).
func writeErrorPage(w http.ResponseWriter, status int, file string) {
	page, err := os.ReadFile(file)
	if err != nil {
		http.Error(w, http.StatusText(status), status)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	w.Write(page)
}
