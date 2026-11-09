"""Carga reproducible y masiva de datos para Bodegas del Atuel.

El modo por defecto supera los mínimos de la etapa 3. Para validar localmente
sin una carga completa se pueden reducir los conteos mediante variables de
entorno, por ejemplo SEED_CLIENTES=100 y SEED_RENGLONES_COMPROBANTE=500.
"""

from __future__ import annotations

import csv
import os
import random
import time
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Iterable, Sequence

import psycopg
from faker import Faker


ROOT = Path(__file__).resolve().parent
SEED = int(os.getenv("SEED", "42"))
BATCH_SIZE = int(os.getenv("SEED_BATCH_SIZE", "5000"))
RESET = os.getenv("SEED_RESET", "1") != "0"

COUNTS = {
    "bodegas": int(os.getenv("SEED_BODEGAS", "10")),
    "fincas": int(os.getenv("SEED_FINCAS", "30")),
    "parcelas": int(os.getenv("SEED_PARCELAS", "12000")),
    "transportistas": int(os.getenv("SEED_TRANSPORTISTAS", "20")),
    "salas": int(os.getenv("SEED_SALAS", "30")),
    "empleados": int(os.getenv("SEED_EMPLEADOS", "100")),
    "vinos": int(os.getenv("SEED_VINOS", "150")),
    "clientes": int(os.getenv("SEED_CLIENTES", "20000")),
    "lotes": int(os.getenv("SEED_LOTES", "12000")),
    "ingresos": int(os.getenv("SEED_INGRESOS", "500")),
    "transferencias": int(os.getenv("SEED_TRANSFERENCIAS", "500")),
    "comprobantes": int(os.getenv("SEED_COMPROBANTES", "20000")),
    "renglones_comprobante": int(
        os.getenv("SEED_RENGLONES_COMPROBANTE", "120000")
    ),
}


def database_url() -> str:
    configured = os.getenv("DATABASE_URL")
    if configured and "******" not in configured:
        return configured
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB", "bodegas_atuel")
    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "postgres")
    return f"postgresql://{user}:{password}@{host}:{port}/{database}"


def chunks(rows: Iterable[Sequence[object]]) -> Iterable[list[Sequence[object]]]:
    batch: list[Sequence[object]] = []
    for row in rows:
        batch.append(row)
        if len(batch) == BATCH_SIZE:
            yield batch
            batch = []
    if batch:
        yield batch


def bulk_insert(
    cur: psycopg.Cursor,
    table: str,
    columns: Sequence[str],
    rows: Iterable[Sequence[object]],
) -> None:
    placeholders = ", ".join(["%s"] * len(columns))
    query = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
    total = 0
    for batch in chunks(rows):
        cur.executemany(query, batch)
        total += len(batch)
    print(f"  {table}: {total:,} filas")


def insert_returning(
    cur: psycopg.Cursor,
    table: str,
    columns: Sequence[str],
    rows: Iterable[Sequence[object]],
    returning: str,
) -> list[object]:
    result: list[object] = []
    columns_sql = ", ".join(columns)
    for batch in chunks(rows):
        values_sql = ", ".join(
            "(" + ", ".join(["%s"] * len(columns)) + ")" for _ in batch
        )
        params = [value for row in batch for value in row]
        cur.execute(
            f"INSERT INTO {table} ({columns_sql}) VALUES {values_sql} "
            f"RETURNING {returning}",
            params,
        )
        result.extend(row[0] for row in cur.fetchall())
    print(f"  {table}: {len(result):,} filas")
    return result


def read_catalog(filename: str) -> list[dict[str, str]]:
    with (ROOT / "catalogos" / filename).open(encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


def cuit(index: int) -> str:
    return f"{20_000_000_000 + index:011d}"


def generate_rows(fake: Faker, catalogs: dict[str, list[dict[str, str]]]):
    rng = random.Random(SEED)
    localities = catalogs["localidades.csv"]
    grapes = catalogs["cepas.csv"]
    pairings = catalogs["maridajes.csv"]
    wine_types = catalogs["tipos_vino.csv"]

    yield "catalogos", {
        "cepas": [
            (row["nombre"], row["tipo"]) for row in grapes
        ],
        "maridajes": [
            (row["nombre"], Decimal(row["temp_servicio"])) for row in pairings
        ],
        "localidades": [
            (
                row["codigo_postal"],
                row["nombre"],
                row["provincia"],
                row["encargado_regional"],
            )
            for row in localities
        ],
        "tipos_vino": [row["tipo"] for row in wine_types],
    }

    bodegas = [
        (cuit(index), f"Bodega {fake.company()}", fake.address()[:200])
        for index in range(1, COUNTS["bodegas"] + 1)
    ]
    yield "bodegas", bodegas

    fincas = [
        (
            f"Finca {fake.last_name()} {index}",
            Decimal(str(rng.randint(80, 500))),
            fake.city(),
            "Mendoza",
        )
        for index in range(1, COUNTS["fincas"] + 1)
    ]
    yield "fincas", fincas

    transportistas = [
        (
            f"Transportes {fake.company()}",
            cuit(1000 + index),
            fake.email(),
            fake.phone_number()[:50],
            fake.address()[:200],
        )
        for index in range(1, COUNTS["transportistas"] + 1)
    ]
    yield "transportistas", transportistas

    yield "salas", [
        (
            fake.street_name(),
            str(rng.randint(1, 5000)),
            rng.choice(["lunes", "martes", "miércoles", "jueves", "domingo"]),
            localities[index % len(localities)]["codigo_postal"],
        )
        for index in range(COUNTS["salas"])
    ]


def load() -> None:
    fake = Faker("es_AR")
    fake.seed_instance(SEED)
    catalogs = {
        filename: read_catalog(filename)
        for filename in (
            "cepas.csv",
            "maridajes.csv",
            "localidades.csv",
            "tipos_vino.csv",
        )
    }
    localities = catalogs["localidades.csv"]
    rng = random.Random(SEED)
    start = time.perf_counter()

    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            if RESET:
                cur.execute(
                    """
                    TRUNCATE TABLE
                        renglon_comprobante, comprobante,
                        permiso_exportacion, exportador, distribuidor, cliente,
                        renglon_transferencia, transferencia,
                        renglon_ingreso, ingreso,
                        analisis_calidad, lote_uva,
                        stock_sala, stock_deposito,
                        empleado, sala_venta, transportista_localidad,
                        transportista, composicion, vino_maridaje, vino,
                        auditoria_precio, maridaje, parcela, finca,
                        localidad, bodega, cepa
                    RESTART IDENTITY CASCADE
                    """
                )

            catalog_data = next(generate_rows(fake, catalogs))[1]
            bulk_insert(cur, "cepa", ("nombre", "tipo"), catalog_data["cepas"])
            bulk_insert(
                cur,
                "maridaje",
                ("nombre", "temp_servicio"),
                catalog_data["maridajes"],
            )
            bulk_insert(
                cur,
                "localidad",
                ("codigo_postal", "nombre", "provincia", "encargado_regional"),
                catalog_data["localidades"],
            )

            generated = dict(generate_rows(fake, catalogs))
            bulk_insert(cur, "bodega", ("cuit", "razon_social", "domicilio"), generated["bodegas"])
            finca_ids = insert_returning(
                cur,
                "finca",
                ("nombre", "superficie_ha", "departamento", "provincia"),
                generated["fincas"],
                "id_finca",
            )
            transportista_ids = insert_returning(
                cur,
                "transportista",
                ("razon_social", "cuit", "email", "telefono", "domicilio"),
                generated["transportistas"],
                "cod_transportista",
            )
            locality_codes = [row[0] for row in catalog_data["localidades"]]
            sala_ids = insert_returning(
                cur,
                "sala_venta",
                ("calle", "numero", "dia_cierre", "codigo_postal"),
                generated["salas"],
                "id_sala",
            )

            bulk_insert(
                cur,
                "transportista_localidad",
                ("cod_transportista", "codigo_postal"),
                (
                    (transportista_ids[index], locality_codes[index % len(locality_codes)])
                    for index in range(len(transportista_ids))
                ),
            )

            parcela_rows = (
                (
                    finca_ids[index % len(finca_ids)],
                    (index // len(finca_ids)) + 1,
                    Decimal(str(rng.randint(5, 40))),
                    rng.randint(2000, 2022),
                    (index % len(catalog_data["cepas"])) + 1,
                )
                for index in range(COUNTS["parcelas"])
            )
            bulk_insert(
                cur,
                "parcela",
                ("id_finca", "nro_parcela", "superficie", "anio_plantacion", "id_cepa"),
                parcela_rows,
            )

            bulk_insert(
                cur,
                "empleado",
                ("cuit", "nombre", "fecha_ingreso", "salario", "id_sala"),
                (
                    (
                        cuit(5000 + index),
                        fake.name(),
                        date(2010, 1, 1) + timedelta(days=rng.randint(0, 5000)),
                        Decimal(str(rng.randint(400_000, 1_200_000))),
                        sala_ids[index % len(sala_ids)],
                    )
                    for index in range(COUNTS["empleados"])
                ),
            )

            wine_rows = (
                (
                    f"{rng.choice(['Reserva', 'Joven', 'Gran'])} {rng.choice(['Malbec', 'Blend', 'Chardonnay'])} {index}",
                    rng.choice(catalog_data["tipos_vino"]),
                    rng.randint(2015, 2025),
                    rng.choice([375, 750, 1500]),
                    Decimal(str(rng.randint(5, 20))),
                    Decimal(str(rng.randint(1500, 25000))),
                    cuit(1 + index % COUNTS["bodegas"]),
                )
                for index in range(COUNTS["vinos"])
            )
            wine_ids = insert_returning(
                cur,
                "vino",
                ("nombre", "tipo", "anada", "volumen_ml", "graduacion", "precio", "cuit_bodega"),
                wine_rows,
                "cod_vino",
            )
            bulk_insert(
                cur,
                "composicion",
                ("cod_vino", "id_cepa", "porcentaje"),
                ((wine_id, (index % len(catalog_data["cepas"])) + 1, 100) for index, wine_id in enumerate(wine_ids)),
            )
            bulk_insert(
                cur,
                "vino_maridaje",
                ("cod_vino", "id_maridaje"),
                ((wine_id, (index % len(catalog_data["maridajes"])) + 1) for index, wine_id in enumerate(wine_ids)),
            )
            cur.execute("UPDATE vino SET precio = precio + 1")
            print(f"  auditoria_precio: {cur.rowcount:,} filas")

            client_rows = (
                (
                    fake.company(),
                    rng.choice(["DNI", "CUIT", "PAS"]),
                    f"{index:08d}",
                    fake.address()[:200],
                    localities[index % len(localities)]["nombre"],
                    date(2020, 1, 1) + timedelta(days=rng.randint(0, 2000)),
                    rng.choice(["socio", "distribuidor", "exportador"]),
                )
                for index in range(COUNTS["clientes"])
            )
            client_ids = insert_returning(
                cur,
                "cliente",
                ("razon_social", "tipo_doc", "nro_doc", "direccion", "localidad", "fecha_alta", "tipo_cliente"),
                client_rows,
                "id_cliente",
            )
            bulk_insert(
                cur,
                "distribuidor",
                ("id_cliente", "zona_cobertura", "nro_habilitacion"),
                (
                    (client_id, "Mendoza", f"HAB-{client_id}")
                    for index, client_id in enumerate(client_ids)
                    if index % 3 == 0
                ),
            )
            exporter_ids = [client_id for index, client_id in enumerate(client_ids) if index % 3 == 1]
            bulk_insert(
                cur,
                "exportador",
                ("id_cliente", "pais_destino"),
                ((client_id, rng.choice(["Chile", "Brasil", "España"])) for client_id in exporter_ids),
            )
            bulk_insert(
                cur,
                "permiso_exportacion",
                ("fecha_emision", "fecha_vencimiento", "id_cliente_exportador"),
                (
                    (date(2025, 1, 1), date(2026, 12, 31), client_id)
                    for client_id in exporter_ids[: max(1, len(exporter_ids) // 2)]
                ),
            )

            lot_rows = (
                (
                    2020 + index % 6,
                    date(2020 + index % 6, 2, 1) + timedelta(days=index % 60),
                    Decimal(str(rng.randint(500, 5000))),
                    finca_ids[index % len(finca_ids)],
                    (index // len(finca_ids)) + 1,
                    cuit(1 + index % COUNTS["bodegas"]),
                )
                for index in range(COUNTS["lotes"])
            )
            lot_ids = insert_returning(
                cur,
                "lote_uva",
                ("anio_campana", "fecha_cosecha", "kilos", "id_finca", "nro_parcela", "cuit_bodega"),
                lot_rows,
                "nro_lote",
            )
            bulk_insert(
                cur,
                "analisis_calidad",
                ("fecha", "brix", "ph", "acidez", "nro_lote"),
                (
                    (date(2020, 3, 1), Decimal("24.00"), Decimal("3.40"), Decimal("5.20"), lot_id)
                    for lot_id in lot_ids
                ),
            )

            bulk_insert(
                cur,
                "stock_deposito",
                ("cod_vino", "cantidad"),
                ((wine_id, 100_000) for wine_id in wine_ids),
            )
            bulk_insert(
                cur,
                "stock_sala",
                ("id_sala", "cod_vino", "cantidad"),
                ((sala_id, wine_id, 10_000) for sala_id in sala_ids for wine_id in wine_ids),
            )

            ingreso_ids = insert_returning(
                cur,
                "ingreso",
                ("cod_transportista", "cuit_bodega"),
                (
                    (transportista_ids[index % len(transportista_ids)], cuit(1 + index % COUNTS["bodegas"]))
                    for index in range(COUNTS["ingresos"])
                ),
                "cod_ingreso",
            )
            bulk_insert(
                cur,
                "renglon_ingreso",
                ("cod_ingreso", "cod_vino", "cantidad"),
                ((ingreso_id, wine_ids[index % len(wine_ids)], 100) for index, ingreso_id in enumerate(ingreso_ids)),
            )
            transfer_ids = insert_returning(
                cur,
                "transferencia",
                ("id_sala_solicitante",),
                ((sala_ids[index % len(sala_ids)],) for index in range(COUNTS["transferencias"])),
                "nro_transferencia",
            )
            bulk_insert(
                cur,
                "renglon_transferencia",
                ("nro_transferencia", "cod_vino", "cantidad"),
                ((transfer_id, wine_ids[index % len(wine_ids)], 10) for index, transfer_id in enumerate(transfer_ids)),
            )

            comprobante_ids = insert_returning(
                cur,
                "comprobante",
                ("id_cliente", "id_sala"),
                ((client_ids[index % len(client_ids)], sala_ids[index % len(sala_ids)]) for index in range(COUNTS["comprobantes"])),
                "nro_comprobante",
            )
            line_count = COUNTS["renglones_comprobante"]
            sales_rows = (
                (
                    comprobante_ids[index % len(comprobante_ids)],
                    wine_ids[(index // len(comprobante_ids)) % len(wine_ids)],
                    1,
                    1000,
                )
                for index in range(line_count)
            )
            bulk_insert(
                cur,
                "renglon_comprobante",
                ("nro_comprobante", "cod_vino", "cantidad", "precio_unitario"),
                sales_rows,
            )
            conn.commit()

    elapsed = time.perf_counter() - start
    print(f"Carga finalizada en {elapsed:.2f} segundos.")
    print(f"Semilla utilizada: {SEED}")


if __name__ == "__main__":
    load()
