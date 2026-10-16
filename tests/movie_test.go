package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/lib/pq"

	dbsqlc "tp/db/sqlc"
)

// newQueries abre la conexión a la base de prueba y la cierra sola al terminar el test.
func newQueries(t *testing.T) *dbsqlc.Queries {
	t.Helper()

	db, err := sql.Open(
		"postgres",
		"host=localhost port=5432 user=postgres password=postgres dbname=moviesdb sslmode=disable",
	)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })

	return dbsqlc.New(db)
}

// createTestMovie inserta una película para que cada test parta de sus propios datos,
// y la borra al finalizar para no dejar basura en la base.
func createTestMovie(t *testing.T, ctx context.Context, q *dbsqlc.Queries) dbsqlc.CreateMovieRow {
	t.Helper()

	movie, err := q.CreateMovie(ctx, dbsqlc.CreateMovieParams{
		Title:       "Interstellar",
		Description: "Ciencia ficción",
		ReleaseDate: time.Date(2014, 11, 7, 0, 0, 0, 0, time.UTC),
		Duration:    169,
	})
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() { q.DeleteMovie(ctx, movie.ID) })

	return movie
}

func TestCreateMovie(t *testing.T) {
	ctx := context.Background()
	q := newQueries(t)

	movie := createTestMovie(t, ctx, q)

	// Verifica que la base devolvió los datos que insertamos
	if movie.Title != "Interstellar" {
		t.Errorf("esperaba Interstellar, obtuve %s", movie.Title)
	}
	if movie.Duration != 169 {
		t.Errorf("esperaba duración 169, obtuve %d", movie.Duration)
	}
}

func TestGetMovieByID(t *testing.T) {
	ctx := context.Background()
	q := newQueries(t)

	movie := createTestMovie(t, ctx, q)

	found, err := q.GetMovieByID(ctx, movie.ID)
	if err != nil {
		t.Fatal(err)
	}

	if found.Title != "Interstellar" {
		t.Errorf("esperaba Interstellar, obtuve %s", found.Title)
	}
}

func TestListMovies(t *testing.T) {
	ctx := context.Background()
	q := newQueries(t)

	createTestMovie(t, ctx, q)

	movies, err := q.ListMovies(ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(movies) == 0 {
		t.Error("esperaba al menos una película")
	}
}

func TestUpdateMovie(t *testing.T) {
	ctx := context.Background()
	q := newQueries(t)

	movie := createTestMovie(t, ctx, q)

	err := q.UpdateMovie(ctx, dbsqlc.UpdateMovieParams{
		ID:          movie.ID,
		Title:       "Interstellar Updated",
		Description: "Descripción actualizada",
		ReleaseDate: movie.ReleaseDate,
		Duration:    170,
	})
	if err != nil {
		t.Fatal(err)
	}

	// Se vuelve a leer de la base para confirmar que el cambio se persistió
	updated, err := q.GetMovieByID(ctx, movie.ID)
	if err != nil {
		t.Fatal(err)
	}

	if updated.Title != "Interstellar Updated" {
		t.Errorf("esperaba Interstellar Updated, obtuve %s", updated.Title)
	}
	if updated.Duration != 170 {
		t.Errorf("esperaba duración 170, obtuve %d", updated.Duration)
	}
}

func TestDeleteMovie(t *testing.T) {
	ctx := context.Background()
	q := newQueries(t)

	movie := createTestMovie(t, ctx, q)

	if err := q.DeleteMovie(ctx, movie.ID); err != nil {
		t.Fatal(err)
	}

	// Tras borrar, buscarla debe fallar con sql.ErrNoRows
	_, err := q.GetMovieByID(ctx, movie.ID)
	if err != sql.ErrNoRows {
		t.Errorf("esperaba sql.ErrNoRows, obtuve %v", err)
	}
}
