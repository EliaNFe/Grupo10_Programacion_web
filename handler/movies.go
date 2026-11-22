package handler

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"

	"tp/service"
	"tp/views"
)

const dateLayout = "2006-01-02"

type Handler struct {
	Service *service.MovieService
}

func New(s *service.MovieService) *Handler {
	return &Handler{Service: s}
}

// IndexPage atiende GET /: obtiene las películas desde el service y renderiza la vista SSR completa.
func (h *Handler) IndexPage(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		writeErrorPage(w, http.StatusNotFound, "exceptions/error.html")
		return
	}
	if r.Method != http.MethodGet {
		writeErrorPage(w, http.StatusMethodNotAllowed, "exceptions/error_method.html")
		return
	}

	movies, err := h.Service.List(r.Context())
	if err != nil {
		fmt.Printf("Error al listar las películas: %s\n", err)
		http.Error(w, "No se pudieron obtener las películas", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := views.IndexPage(movies).Render(r.Context(), w); err != nil {
		fmt.Printf("Error al renderizar la página: %s\n", err)
	}
}

// CreateMovie atiende POST /movies con HTMX:
// Parsea el formulario, delega la creación al service, vuelve a consultar la lista
// y devuelve ÚNICAMENTE el HTML de views.MovieList para que HTMX lo inserte en el target.
func (h *Handler) CreateMovie(w http.ResponseWriter, r *http.Request) {
	input, err := parseMovieForm(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if _, err := h.Service.Create(r.Context(), input); err != nil {
		var validationErr *service.ValidationError
		if errors.As(err, &validationErr) {
			http.Error(w, validationErr.Msg, http.StatusBadRequest)
			return
		}
		fmt.Printf("Error al guardar la película: %s\n", err)
		http.Error(w, "No se pudo guardar la película", http.StatusInternalServerError)
		return
	}

	// Consultamos la lista completa con la nueva película
	movies, err := h.Service.List(r.Context())
	if err != nil {
		fmt.Printf("Error al listar las películas tras crear: %s\n", err)
		http.Error(w, "Error al actualizar la lista", http.StatusInternalServerError)
		return
	}

	// HTMX recibe este fragmento y reemplaza el contenedor sin recargar la página
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := views.MovieList(movies).Render(r.Context(), w); err != nil {
		fmt.Printf("Error al renderizar MovieList: %s\n", err)
	}
}

// DeleteMovie atiende DELETE /movies/{id} con HTMX:
// Parsea el id, elimina la película y responde 200 OK vacío para que HTMX elimine la fila del DOM.
func (h *Handler) DeleteMovie(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 32)
	if err != nil || id <= 0 {
		http.Error(w, "ID inválido", http.StatusBadRequest)
		return
	}

	if err := h.Service.Delete(r.Context(), int32(id)); err != nil {
		fmt.Printf("Error al eliminar la película: %s\n", err)
		http.Error(w, "No se pudo eliminar la película", http.StatusInternalServerError)
		return
	}

	// Respuesta 200 vacía: HTMX borra el <tr> targeteado
	w.WriteHeader(http.StatusOK)
}

// parseMovieForm solo se encarga de parsear el formato HTTP del formulario a tipos de Go.
func parseMovieForm(r *http.Request) (service.MovieInput, error) {
	if err := r.ParseForm(); err != nil {
		return service.MovieInput{}, errors.New("Formulario inválido")
	}

	releaseDate, err := time.Parse(dateLayout, r.PostFormValue("release_date"))
	if err != nil {
		return service.MovieInput{}, errors.New("la fecha de estreno debe tener formato YYYY-MM-DD")
	}

	duration, err := strconv.ParseInt(r.PostFormValue("duration"), 10, 32)
	if err != nil {
		return service.MovieInput{}, errors.New("la duración debe ser un número entero mayor a 0")
	}

	return service.MovieInput{
		Title:       r.PostFormValue("title"),
		Description: r.PostFormValue("description"),
		ReleaseDate: releaseDate,
		Duration:    int32(duration),
	}, nil
}

// writeErrorPage responde con el código de estado indicado y el HTML de la página de error.
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
