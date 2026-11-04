// Misma URL base que el servidor Go (se sirve desde él, así que no hay problemas de CORS)
const API_URL = "/movies";

const form = document.getElementById("movie-form");
const list = document.getElementById("movie-list");
const message = document.getElementById("message");
const formTitle = document.getElementById("form-title");
const submitBtn = document.getElementById("submit-btn");
const cancelBtn = document.getElementById("cancel-btn");

let currentMovies = []; // última lista recibida (para precargar el formulario al editar)
let editingId = null;   // null = modo crear; un id = modo editar

function showMessage(text, isError = true) {
  message.textContent = text;
  message.className = isError ? "message error" : "message ok";
}

// Si la API devuelve {"error": "..."} muestra ese texto; si no, uno genérico
async function errorText(res) {
  try {
    const data = await res.json();
    return data.error || `Error ${res.status}`;
  } catch {
    return `Error ${res.status}`;
  }
}

// ---------- LISTAR (GET /movies) ----------
async function loadMovies() {
  try {
    const res = await fetch(API_URL);
    if (!res.ok) throw new Error(await errorText(res));
    currentMovies = await res.json();
    renderMovies(currentMovies);
  } catch (err) {
    showMessage("No se pudo cargar la lista: " + err.message);
  }
}

function renderMovies(movies) {
  list.innerHTML = "";

  if (movies.length === 0) {
    const empty = document.createElement("li");
    empty.className = "empty";
    empty.textContent = "Todavía no hay películas cargadas.";
    list.appendChild(empty);
    return;
  }

  for (const m of movies) {
    const li = document.createElement("li");
    li.className = "movie";

    const info = document.createElement("div");
    info.className = "info";

    const title = document.createElement("strong");
    title.textContent = m.title;

    const desc = document.createElement("p");
    desc.textContent = m.description;

    const meta = document.createElement("small");
    meta.textContent = `${m.release_date} · ${m.duration} min`;

    info.append(title, desc, meta);

    const actions = document.createElement("div");
    actions.className = "actions";

    const editBtn = document.createElement("button");
    editBtn.className = "edit";
    editBtn.textContent = "Editar";
    editBtn.dataset.id = m.id;

    const deleteBtn = document.createElement("button");
    deleteBtn.className = "delete";
    deleteBtn.textContent = "Eliminar";
    deleteBtn.dataset.id = m.id; // el id queda guardado en el botón

    actions.append(editBtn, deleteBtn);
    li.append(info, actions);
    list.appendChild(li);
  }
}

// ---------- Modo crear / modo editar ----------
function startEdit(id) {
  const movie = currentMovies.find((m) => String(m.id) === String(id));
  if (!movie) return;

  editingId = movie.id;
  document.getElementById("title").value = movie.title;
  document.getElementById("description").value = movie.description;
  document.getElementById("release_date").value = movie.release_date;
  document.getElementById("duration").value = movie.duration;

  formTitle.textContent = "Editar película";
  submitBtn.textContent = "Guardar cambios";
  cancelBtn.hidden = false;
  showMessage("", false);
  form.scrollIntoView({ behavior: "smooth" });
  document.getElementById("title").focus();
}

function resetForm() {
  form.reset();
  editingId = null;
  formTitle.textContent = "Agregar película";
  submitBtn.textContent = "Agregar";
  cancelBtn.hidden = true;
}

cancelBtn.addEventListener("click", () => {
  resetForm();
  showMessage("", false);
});

// ---------- CREAR (POST) o EDITAR (PUT) ----------
form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const movie = {
    title: document.getElementById("title").value,
    description: document.getElementById("description").value,
    release_date: document.getElementById("release_date").value, // YYYY-MM-DD
    duration: parseInt(document.getElementById("duration").value, 10),
  };

  const isEditing = editingId !== null;
  const url = isEditing ? `${API_URL}/${editingId}` : API_URL;
  const method = isEditing ? "PUT" : "POST";

  try {
    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(movie),
    });
    if (!res.ok) throw new Error(await errorText(res));

    resetForm();
    showMessage(isEditing ? "Película actualizada" : "Película agregada", false);
    await loadMovies(); // vuelve a pedir la lista completa
  } catch (err) {
    showMessage(err.message);
  }
});

// ---------- EDITAR / BORRAR con delegación de eventos ----------
// Un solo listener en la lista; sirve para los botones actuales y los futuros.
list.addEventListener("click", async (event) => {
  const editBtn = event.target.closest("button.edit");
  if (editBtn) {
    startEdit(editBtn.dataset.id);
    return;
  }

  const deleteBtn = event.target.closest("button.delete");
  if (!deleteBtn) return;

  const id = deleteBtn.dataset.id;
  try {
    const res = await fetch(`${API_URL}/${id}`, { method: "DELETE" });
    if (!res.ok) throw new Error(await errorText(res)); // el 204 no trae body

    // Si justo se estaba editando la película borrada, se sale del modo editar
    if (String(editingId) === String(id)) resetForm();

    showMessage("Película eliminada", false);
    await loadMovies();
  } catch (err) {
    showMessage(err.message);
  }
});

// Al cargar la página
loadMovies();