import os
import secrets
import string

import pytest
from fastapi.testclient import TestClient
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from api.app.main import create_app


@pytest.fixture(scope="module")
def test_pool():
    database_url = os.getenv("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("Configure TEST_DATABASE_URL para ejecutar las pruebas PostgreSQL.")

    pool = ConnectionPool(
        conninfo=database_url,
        kwargs={"row_factory": dict_row},
        min_size=1,
        max_size=4,
        open=True,
        name="bodegas-test",
    )
    pool.wait(timeout=10)
    with pool.connection() as connection:
        database_name = connection.execute(
            "SELECT current_database() AS name"
        ).fetchone()["name"]
    if not database_name.endswith("_test"):
        pool.close()
        pytest.fail("TEST_DATABASE_URL debe apuntar a una base cuyo nombre termine en _test.")

    yield pool
    pool.close()


@pytest.fixture(scope="module")
def api_client(test_pool):
    with TestClient(create_app(test_pool)) as client:
        yield client


@pytest.fixture(scope="module")
def test_data(test_pool):
    suffix = "".join(secrets.choice(string.digits) for _ in range(10))
    cuit = f"2{suffix}"
    postal_code = f"T{secrets.token_hex(5)}"
    document_number = secrets.token_hex(8)

    with test_pool.connection() as connection:
        with connection.transaction():
            connection.execute(
                """
                INSERT INTO bodega (cuit, razon_social, domicilio)
                VALUES (%s, %s, %s)
                """,
                (cuit, f"Bodega API Test {suffix}", "Domicilio de prueba"),
            )
            cepa = connection.execute(
                """
                INSERT INTO cepa (nombre, tipo)
                VALUES (%s, 'tinta')
                RETURNING id_cepa
                """,
                (f"Malbec API Test {suffix}",),
            ).fetchone()
            wine = connection.execute(
                """
                INSERT INTO vino
                    (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
                VALUES (%s, 'tinto', 2025, 750, 13, 100, %s)
                RETURNING cod_vino
                """,
                (f"Vino API Test {suffix}", cuit),
            ).fetchone()
            connection.execute(
                """
                INSERT INTO composicion (cod_vino, id_cepa, porcentaje)
                VALUES (%s, %s, 100)
                """,
                (wine["cod_vino"], cepa["id_cepa"]),
            )
            connection.execute(
                """
                INSERT INTO localidad
                    (codigo_postal, nombre, provincia, encargado_regional)
                VALUES (%s, %s, 'Mendoza', 'Prueba')
                """,
                (postal_code, f"Localidad API Test {suffix}"),
            )
            room = connection.execute(
                """
                INSERT INTO sala_venta (calle, numero, dia_cierre, codigo_postal)
                VALUES ('Calle de prueba', '1', 'domingo', %s)
                RETURNING id_sala
                """,
                (postal_code,),
            ).fetchone()
            client = connection.execute(
                """
                INSERT INTO cliente
                    (razon_social, tipo_doc, nro_doc, direccion, localidad, tipo_cliente)
                VALUES (%s, 'DNI', %s, 'Domicilio de prueba', 'San Rafael', 'socio')
                RETURNING id_cliente
                """,
                (f"Cliente API Test {suffix}", document_number),
            ).fetchone()
            connection.execute(
                """
                INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
                VALUES (%s, %s, 0)
                """,
                (room["id_sala"], wine["cod_vino"]),
            )

    yield {
        "cuit_bodega": cuit,
        "id_cepa": cepa["id_cepa"],
        "cod_vino": wine["cod_vino"],
        "id_sala": room["id_sala"],
        "id_cliente": client["id_cliente"],
    }

    with test_pool.connection() as connection:
        with connection.transaction():
            connection.execute(
                "DELETE FROM transferencia WHERE id_sala_solicitante = %s",
                (room["id_sala"],),
            )
            connection.execute(
                "DELETE FROM comprobante WHERE id_cliente = %s",
                (client["id_cliente"],),
            )
            connection.execute(
                "DELETE FROM stock_sala WHERE id_sala = %s AND cod_vino = %s",
                (room["id_sala"], wine["cod_vino"]),
            )
            connection.execute(
                "DELETE FROM cliente WHERE id_cliente = %s",
                (client["id_cliente"],),
            )
            connection.execute(
                "DELETE FROM vino WHERE cod_vino = %s",
                (wine["cod_vino"],),
            )
            connection.execute(
                "DELETE FROM sala_venta WHERE id_sala = %s",
                (room["id_sala"],),
            )
            connection.execute(
                "DELETE FROM localidad WHERE codigo_postal = %s",
                (postal_code,),
            )
            connection.execute(
                "DELETE FROM cepa WHERE id_cepa = %s",
                (cepa["id_cepa"],),
            )
            connection.execute("DELETE FROM bodega WHERE cuit = %s", (cuit,))


def test_negative_wine_price_is_rejected_by_database(api_client, test_data):
    response = api_client.post(
        "/vinos",
        json={
            "nombre": "Precio negativo API Test",
            "tipo": "tinto",
            "anada": 2025,
            "volumen_ml": 750,
            "graduacion": 13,
            "precio": -1,
            "cuit_bodega": test_data["cuit_bodega"],
            "composicion": [{"id_cepa": test_data["id_cepa"], "porcentaje": 100}],
            "maridajes": [],
        },
    )

    assert response.status_code == 422
    assert response.json()["sqlstate"] == "23514"


def test_sale_without_stock_is_rejected_and_rolled_back(api_client, test_data, test_pool):
    response = api_client.post(
        "/comprobantes",
        json={
            "id_cliente": test_data["id_cliente"],
            "id_sala": test_data["id_sala"],
            "renglones": [{"cod_vino": test_data["cod_vino"], "cantidad": 1}],
        },
    )

    assert response.status_code == 409
    assert response.json()["sqlstate"] == "23514"
    with test_pool.connection() as connection:
        count = connection.execute(
            "SELECT count(*) AS total FROM comprobante WHERE id_cliente = %s",
            (test_data["id_cliente"],),
        ).fetchone()["total"]
    assert count == 0


def test_processing_transfer_before_finishing_is_rejected(api_client, test_data):
    created = api_client.post(
        "/transferencias",
        json={"id_sala_solicitante": test_data["id_sala"]},
    )
    assert created.status_code == 201
    nro_transferencia = created.json()["nro_transferencia"]

    response = api_client.post(
        f"/transferencias/{nro_transferencia}/procesar"
    )

    assert response.status_code == 409
    assert response.json()["sqlstate"] == "P0001"
    assert "debe estar terminada" in response.json()["detail"]
