package service

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	dbsqlc "tp/db/sqlc"
)

// ErrNotFound se devuelve cuando la película no existe
var ErrNotFound = errors.New("película no encontrada")

// ValidationError se devuelve cuando los datos no cumplen las reglas
type ValidationError struct {
	Msg string
}

func (e *ValidationError) Error() string { return e.Msg }

// Movie es el modelo que devuelve el service (no depende de sqlc ni de HTTP)
type Movie struct {
	ID          int32
	Title       string
	Description string
	ReleaseDate time.Time
	Duration    int32
}

// MovieInput son los datos de entrada para crear o actualizar
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

// validate limpia los espacios y aplica las reglas de negocio
func validate(in MovieInput) (MovieInput, error) {
	in.Title = strings.TrimSpace(in.Title)
	in.Description = strings.TrimSpace(in.Description)

	if in.Title == "" {
		return in, &ValidationError{"el título no puede estar vacío"}
	}
	if len(in.Title) > 255 {
		return in, &ValidationError{"el título no puede superar los 255 caracteres"}
	}
	if in.Description == "" {
		return in, &ValidationError{"la descripción no puede estar vacía"}
	}
	if len(in.Description) > 255 {
		return in, &ValidationError{"la descripción no puede superar los 255 caracteres"}
	}
	if in.Duration <= 0 {
		return in, &ValidationError{"la duración debe ser mayor a 0"}
	}
	return in, nil
}

func (s *MovieService) Create(ctx context.Context, in MovieInput) (Movie, error) {
	in, err := validate(in)
	if err != nil {
		return Movie{}, err
	}

	row, err := s.queries.CreateMovie(ctx, dbsqlc.CreateMovieParams{
		Title:       in.Title,
		Description: in.Description,
		ReleaseDate: in.ReleaseDate,
		Duration:    in.Duration,
	})
	if err != nil {
		return Movie{}, err
	}

	return Movie{row.ID, row.Title, row.Description, row.ReleaseDate, row.Duration}, nil
}

func (s *MovieService) List(ctx context.Context) ([]Movie, error) {
	rows, err := s.queries.ListMovies(ctx)
	if err != nil {
		return nil, err
	}

	movies := make([]Movie, 0, len(rows))
	for _, r := range rows {
		movies = append(movies, Movie{r.ID, r.Title, r.Description, r.ReleaseDate, r.Duration})
	}
	return movies, nil
}

func (s *MovieService) Get(ctx context.Context, id int32) (Movie, error) {
	row, err := s.queries.GetMovieByID(ctx, id)
	if errors.Is(err, sql.ErrNoRows) {
		return Movie{}, ErrNotFound
	}
	if err != nil {
		return Movie{}, err
	}

	return Movie{row.ID, row.Title, row.Description, row.ReleaseDate, row.Duration}, nil
}

func (s *MovieService) Update(ctx context.Context, id int32, in MovieInput) (Movie, error) {
	in, err := validate(in)
	if err != nil {
		return Movie{}, err
	}

	// UpdateMovie no avisa si el id no existe, así que primero se verifica
	if _, err := s.Get(ctx, id); err != nil {
		return Movie{}, err
	}

	err = s.queries.UpdateMovie(ctx, dbsqlc.UpdateMovieParams{
		ID:          id,
		Title:       in.Title,
		Description: in.Description,
		ReleaseDate: in.ReleaseDate,
		Duration:    in.Duration,
	})
	if err != nil {
		return Movie{}, err
	}

	return Movie{id, in.Title, in.Description, in.ReleaseDate, in.Duration}, nil
}

func (s *MovieService) Delete(ctx context.Context, id int32) error {
	return s.queries.DeleteMovie(ctx, id)
}
