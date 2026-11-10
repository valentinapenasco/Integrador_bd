const API_URL = (import.meta.env.VITE_API_URL || "http://localhost:8000").replace(/\/$/, "");

function formatErrorDetail(detail) {
  if (Array.isArray(detail)) {
    return detail
      .map((item) => {
        const location = Array.isArray(item.loc) ? item.loc.join(".") : "";
        return location ? `${location}: ${item.msg}` : item.msg;
      })
      .join(" | ");
  }
  if (detail && typeof detail === "object") return JSON.stringify(detail);
  return detail || "La API no pudo completar la operación.";
}

export async function api(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(formatErrorDetail(body.detail));
  }
  return body;
}

export const getCatalogs = () =>
  Promise.all([
    api("/cepas"),
    api("/maridajes"),
    api("/bodegas"),
    api("/salas"),
  ]).then(([cepas, maridajes, bodegas, salas]) => ({ cepas, maridajes, bodegas, salas }));
