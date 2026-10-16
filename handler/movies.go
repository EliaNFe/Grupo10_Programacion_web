package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"tp/service"
)

const dateLayout = "2006-01-02"

type Handler struct {
	Service *service.MovieService
}

func New(s *service.MovieService) *Handler {
	return &Handler{Service: s}
}

// Lo que llega en el JSON de POST y PUT
type movieRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	ReleaseDate string `json:"release_date"` // formato YYYY-MM-DD
	Duration    int32  `json:"duration"`
}

// Lo que se devuelve en el JSON en un GET
type movieResponse struct {
	ID          int32  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	ReleaseDate string `json:"release_date"`
	Duration    int32  `json:"duration"`
}

func toResponse(m service.Movie) movieResponse {
	return movieResponse{
		ID:          m.ID,
		Title:       m.Title,
		Description: m.Description,
		ReleaseDate: m.ReleaseDate.Format(dateLayout),
		Duration:    m.Duration,
	}
}

// ---------- helpers ----------

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func parseID(r *http.Request) (int32, error) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 32)
	if err != nil || id <= 0 {
		return 0, errors.New("id inválido")
	}
	return int32(id), nil
}

// Solo se ocupa del formato HTTP: lee el JSON y parsea la fecha.
// Las reglas de negocio las valida el service.
func decodeMovie(r *http.Request) (service.MovieInput, error) {
	var req movieRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return service.MovieInput{}, errors.New("JSON inválido")
	}

	date, err := time.Parse(dateLayout, req.ReleaseDate)
	if err != nil {
		return service.MovieInput{}, errors.New("release_date debe tener formato YYYY-MM-DD")
	}

	return service.MovieInput{
		Title:       req.Title,
		Description: req.Description,
		ReleaseDate: date,
		Duration:    req.Duration,
	}, nil
}

// Traduce los errores del service a códigos HTTP
func handleServiceError(w http.ResponseWriter, err error) {
	var validationErr *service.ValidationError

	switch {
	case errors.As(err, &validationErr):
		writeError(w, http.StatusBadRequest, validationErr.Msg)
	case errors.Is(err, service.ErrNotFound):
		writeError(w, http.StatusNotFound, err.Error())
	default:
		writeError(w, http.StatusInternalServerError, "error interno del servidor")
	}
}

// ---------- handlers ----------

// POST /movies
func (h *Handler) CreateMovie(w http.ResponseWriter, r *http.Request) {
	input, err := decodeMovie(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	movie, err := h.Service.Create(r.Context(), input)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, toResponse(movie))
}

// GET /movies
func (h *Handler) ListMovies(w http.ResponseWriter, r *http.Request) {
	movies, err := h.Service.List(r.Context())
	if err != nil {
		handleServiceError(w, err)
		return
	}

	result := make([]movieResponse, 0, len(movies))
	for _, m := range movies {
		result = append(result, toResponse(m))
	}

	writeJSON(w, http.StatusOK, result)
}

// GET /movies/{id}
func (h *Handler) GetMovie(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	movie, err := h.Service.Get(r.Context(), id)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, toResponse(movie))
}

// PUT /movies/{id}
func (h *Handler) UpdateMovie(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	input, err := decodeMovie(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	movie, err := h.Service.Update(r.Context(), id, input)
	if err != nil {
		handleServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, toResponse(movie))
}

// DELETE /movies/{id}
func (h *Handler) DeleteMovie(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := h.Service.Delete(r.Context(), id); err != nil {
		handleServiceError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
