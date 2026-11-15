-- name: CreateMovie :one
INSERT INTO movies (title, description, release_date, duration)
VALUES ($1, $2, $3, $4)
RETURNING id, title, description, release_date, duration;

-- name: GetMovieByID :one
SELECT id, title, description, release_date, duration
FROM movies
WHERE id = $1;

-- name: ListMovies :many
SELECT id, title, description, release_date, duration
FROM movies;

-- name: UpdateMovie :exec
UPDATE movies
SET title = $2,
    description = $3,
    release_date = $4,
    duration = $5
WHERE id = $1;

-- name: DeleteMovie :exec
DELETE FROM movies
WHERE id = $1;