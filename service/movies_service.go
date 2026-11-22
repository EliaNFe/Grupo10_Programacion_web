package service

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	dbsqlc "tp/db/sqlc"
)

// ValidationError se devuelve cuando los datos no cumplen las reglas de negocio.
type ValidationError struct {
	Msg string
}

func (e *ValidationError) Error() string { return e.Msg }

// MovieInput contiene los datos de entrada ya parseados desde la capa HTTP.
type MovieInput struct {
	Title       string
	Description string
	ReleaseDate time.Time
	Duration    int32
}

type MovieService struct {
	queries *dbsqlc.Queries
}

func NewMovieService(q *dbsqlc.Queries) *MovieService {
	return &MovieService{queries: q}
}

// validate limpia espacios y valida las reglas de negocio de una película.
func validate(in MovieInput) (MovieInput, error) {
	in.Title = strings.TrimSpace(in.Title)
	in.Description = strings.TrimSpace(in.Description)

	if in.Title == "" {
		return in, &ValidationError{Msg: "el título no puede estar vacío"}
	}
	if utf8.RuneCountInString(in.Title) > 255 {
		return in, &ValidationError{Msg: "el título no puede superar los 255 caracteres"}
	}
	if in.Description == "" {
		return in, &ValidationError{Msg: "la descripción no puede estar vacía"}
	}
	if utf8.RuneCountInString(in.Description) > 255 {
		return in, &ValidationError{Msg: "la descripción no puede superar los 255 caracteres"}
	}
	if in.Duration <= 0 {
		return in, &ValidationError{Msg: "la duración debe ser un número entero mayor a 0"}
	}
	return in, nil
}

func (s *MovieService) Create(ctx context.Context, in MovieInput) (dbsqlc.CreateMovieRow, error) {
	in, err := validate(in)
	if err != nil {
		return dbsqlc.CreateMovieRow{}, err
	}

	return s.queries.CreateMovie(ctx, dbsqlc.CreateMovieParams{
		Title:       in.Title,
		Description: in.Description,
		ReleaseDate: in.ReleaseDate,
		Duration:    in.Duration,
	})
}

func (s *MovieService) List(ctx context.Context) ([]dbsqlc.ListMoviesRow, error) {
	return s.queries.ListMovies(ctx)
}

func (s *MovieService) Delete(ctx context.Context, id int32) error {
	return s.queries.DeleteMovie(ctx, id)
}
