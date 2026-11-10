from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from psycopg import Error


def postgres_error_response(sqlstate: str | None, message: str) -> tuple[int, str]:
    if sqlstate == "23514" and message.lower().startswith("stock insuficiente"):
        return 409, "Conflicto: stock insuficiente."
    if sqlstate == "23505":
        return 409, "Conflicto: el registro ya existe."
    if sqlstate == "23503":
        return 409, "Conflicto: el registro relacionado no existe o tiene dependencias."
    if sqlstate == "23514":
        return 422, message
    if sqlstate == "23502":
        return 422, "Los datos no cumplen las reglas de la base de datos."
    if sqlstate == "P0001":
        return 409, message
    if sqlstate == "22P02":
        return 400, "El formato de uno de los valores no es válido."
    if sqlstate in {"40001", "40P01"}:
        return 503, "Conflicto transitorio de concurrencia; reintente la operación."
    return 500, "Error interno al acceder a la base de datos."


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(Error)
    async def postgres_error_handler(
        request: Request, error: Error
    ) -> JSONResponse:
        message = getattr(error.diag, "message_primary", None) or str(error)
        status_code, detail = postgres_error_response(error.sqlstate, message)
        headers = {"Retry-After": "1"} if status_code == 503 else None
        content = {"detail": detail}
        if error.sqlstate:
            content["sqlstate"] = error.sqlstate
        return JSONResponse(
            status_code=status_code,
            content=content,
            headers=headers,
        )
