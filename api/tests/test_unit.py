from contextlib import contextmanager
from typing import Any

from fastapi.testclient import TestClient

from api.app import dao
from api.app.errors import postgres_error_response
from api.app.main import create_app


class FakeCursor:
    def __init__(self, row: dict[str, Any] | None = None):
        self.row = row

    def fetchone(self) -> dict[str, Any] | None:
        return self.row

    def fetchall(self) -> list[Any]:
        return []


class FakeConnection:
    def __init__(self):
        self.last_query: str | None = None
        self.last_params: tuple[Any, ...] = ()

    def execute(self, query: str, params: tuple[Any, ...] = ()) -> FakeCursor:
        self.last_query = query
        self.last_params = params
        if query == "SELECT 1 AS ok":
            return FakeCursor({"ok": 1})
        return FakeCursor()

    @contextmanager
    def transaction(self):
        yield


class FakePool:
    def __init__(self):
        self.connection_instance = FakeConnection()

    def connection(self):
        @contextmanager
        def acquire():
            yield self.connection_instance

        return acquire()


def test_health_endpoint_checks_database_connection():
    with TestClient(create_app(FakePool())) as client:
        response = client.get("/salud")

    assert response.status_code == 200
    assert response.json() == {"estado": "ok"}


def test_openapi_lists_required_resource_routes():
    with TestClient(create_app(FakePool())) as client:
        paths = client.get("/openapi.json").json()["paths"]

    required = {
        "/salud",
        "/vinos",
        "/vinos/{cod_vino}",
        "/clientes",
        "/clientes/{id_cliente}",
        "/comprobantes",
        "/transferencias",
        "/transferencias/{nro_transferencia}/procesar",
        "/ingresos",
        "/ingresos/{cod_ingreso}/terminar",
        "/ingresos/{cod_ingreso}/procesar",
        "/reportes/top-vinos",
        "/reportes/ventas-por-sala",
        "/reportes/vinos-sin-stock",
        "/reportes/transportista-activo",
        "/reportes/trazabilidad/{cod_vino}",
    }
    assert required <= paths.keys()
    assert {"get", "post"} <= paths["/vinos"].keys()
    assert {"get", "put", "delete"} <= paths["/vinos/{cod_vino}"].keys()
    assert {"get", "post"} <= paths["/clientes"].keys()
    assert {"get", "put", "delete"} <= paths["/clientes/{id_cliente}"].keys()


def test_wine_filter_values_are_bound_as_sql_parameters():
    connection = FakeConnection()
    attack_like_filter = "Bodega' OR '1'='1"

    dao.list_wines(
        connection,
        tipo=None,
        id_cepa=None,
        bodega=attack_like_filter,
        anada=None,
        limit=20,
        offset=0,
    )

    assert attack_like_filter not in connection.last_query
    assert connection.last_params[4:6] == (attack_like_filter, attack_like_filter)


def test_frontend_origin_is_allowed_for_browser_requests():
    with TestClient(create_app(FakePool())) as client:
        response = client.options(
            "/vinos",
            headers={
                "Origin": "http://localhost:8080",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:8080"


def test_unique_violation_maps_to_conflict():
    assert postgres_error_response("23505", "duplicate") == (
        409,
        "Conflicto: el registro ya existe.",
    )


def test_foreign_key_violation_maps_to_conflict():
    assert postgres_error_response("23503", "missing") == (
        409,
        "Conflicto: el registro relacionado no existe o tiene dependencias.",
    )


def test_check_violation_maps_to_unprocessable_entity():
    assert postgres_error_response("23514", "invalid price") == (
        422,
        "Los datos no cumplen las reglas de la base de datos.",
    )


def test_insufficient_stock_maps_to_conflict():
    assert postgres_error_response("23514", "Stock insuficiente para vino 7") == (
        409,
        "Conflicto: stock insuficiente.",
    )


def test_procedure_rule_error_preserves_database_message():
    message = "La transferencia 5 debe estar terminada"
    assert postgres_error_response("P0001", message) == (409, message)


def test_deadlock_suggests_retry():
    assert postgres_error_response("40P01", "deadlock") == (
        503,
        "Conflicto transitorio de concurrencia; reintente la operación.",
    )
