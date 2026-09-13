package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/lib/pq"

	dbsqlc "tp2/db/sqlc"
)

func TestMovieCRUD(t *testing.T) {
	db, err := sql.Open(
		"postgres",
		"host=localhost port=5432 user=postgres password=postgres dbname=moviesdb sslmode=disable",
	)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	ctx := context.Background()
	queries := dbsqlc.New(db)

	releaseDate := time.Date(2014, 11, 7, 0, 0, 0, 0, time.UTC)

	// CREATE
	movie, err := queries.CreateMovie(ctx, dbsqlc.CreateMovieParams{
		Title:       "Interstellar",
		Description: "Ciencia ficción",
		ReleaseDate: releaseDate,
		Duration:    169,
	})
	if err != nil {
		t.Fatal(err)
	}

	// READ
	found, err := queries.GetMovieByID(ctx, movie.ID)
	if err != nil {
		t.Fatal(err)
	}

	if found.Title != "Interstellar" {
		t.Errorf("esperaba Interstellar, obtuve %s", found.Title)
	}

	// LIST
	movies, err := queries.ListMovies(ctx)
	if err != nil {
		t.Fatal(err)
	}

	if len(movies) == 0 {
		t.Error("esperaba al menos una película")
	}

	// UPDATE
	err = queries.UpdateMovie(ctx, dbsqlc.UpdateMovieParams{
		ID:          movie.ID,
		Title:       "Interstellar Updated",
		Description: "Descripción actualizada",
		ReleaseDate: releaseDate,
		Duration:    170,
	})
	if err != nil {
		t.Fatal(err)
	}

	updated, err := queries.GetMovieByID(ctx, movie.ID)
	if err != nil {
		t.Fatal(err)
	}

	if updated.Title != "Interstellar Updated" {
		t.Errorf("esperaba Interstellar Updated, obtuve %s", updated.Title)
	}

	// DELETE
	err = queries.DeleteMovie(ctx, movie.ID)
	if err != nil {
		t.Fatal(err)
	}

	_, err = queries.GetMovieByID(ctx, movie.ID)

	if err != sql.ErrNoRows {
		t.Errorf("esperaba sql.ErrNoRows, obtuve %v", err)
	}
}
