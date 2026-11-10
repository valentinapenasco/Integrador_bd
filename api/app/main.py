import os
from contextlib import asynccontextmanager
from typing import Annotated, Any

from fastapi import Depends, FastAPI, HTTPException, Path, Query
from fastapi.middleware.cors import CORSMiddleware
from psycopg import Connection
from psycopg_pool import ConnectionPool

from . import dao
from .db import create_pool, get_connection
from .errors import install_error_handlers
from .schemas import (
    ClientInput,
    DocumentLineInput,
    IngressInput,
    ReceiptInput,
    TransferInput,
    WineInput,
)

ConnectionDependency = Annotated[Connection, Depends(get_connection)]
PositivePathId = Annotated[int, Path(gt=0)]


def create_app(pool: ConnectionPool | None = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        owns_pool = pool is None
        current_pool = pool or create_pool()
        if owns_pool:
            current_pool.open()
            current_pool.wait(timeout=30)
        app.state.pool = current_pool
        try:
            yield
        finally:
            if owns_pool:
                current_pool.close()

    app = FastAPI(
        title="Bodegas del Atuel API",
        description="API REST local para el sistema de gestión de Bodegas del Atuel.",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            origin.strip()
            for origin in os.getenv(
                "CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080"
            ).split(",")
            if origin.strip()
        ],
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Content-Type"],
        expose_headers=["Retry-After"],
    )
    install_error_handlers(app)

    @app.get("/salud", tags=["Salud"])
    def health(connection: ConnectionDependency) -> dict[str, str]:
        dao.check_database(connection)
        return {"estado": "ok"}

    @app.get("/cepas", tags=["Catalogos"])
    def list_grape_varieties(connection: ConnectionDependency) -> list[Any]:
        return dao.list_grape_varieties(connection)

    @app.get("/maridajes", tags=["Catalogos"])
    def list_pairings(connection: ConnectionDependency) -> list[Any]:
        return dao.list_pairings(connection)

    @app.get("/bodegas", tags=["Catalogos"])
    def list_wineries(connection: ConnectionDependency) -> list[Any]:
        return dao.list_wineries(connection)

    @app.get("/salas", tags=["Catalogos"])
    def list_sales_rooms(connection: ConnectionDependency) -> list[Any]:
        return dao.list_sales_rooms(connection)

    @app.get("/vinos", tags=["Vinos"])
    def list_wines(
        connection: ConnectionDependency,
        tipo: str | None = None,
        id_cepa: Annotated[int | None, Query(gt=0)] = None,
        bodega: str | None = None,
        anada: int | None = None,
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
        offset: Annotated[int, Query(ge=0)] = 0,
    ) -> dict[str, Any]:
        if tipo is not None and tipo not in {"tinto", "blanco", "rosado", "espumante"}:
            raise HTTPException(status_code=422, detail="El tipo de vino no es válido.")
        return {
            "items": dao.list_wines(
                connection,
                tipo=tipo,
                id_cepa=id_cepa,
                bodega=bodega,
                anada=anada,
                limit=limit,
                offset=offset,
            ),
            "limit": limit,
            "offset": offset,
        }

    @app.get("/vinos/{cod_vino}", tags=["Vinos"])
    def get_wine(
        cod_vino: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        wine = dao.get_wine(connection, cod_vino)
        if wine is None:
            raise HTTPException(status_code=404, detail="No existe el vino solicitado.")
        return wine

    @app.post("/vinos", status_code=201, tags=["Vinos"])
    def create_wine(wine: WineInput, connection: ConnectionDependency) -> Any:
        with connection.transaction():
            created = dao.insert_wine(connection, wine)
            cod_vino = created["cod_vino"]
            dao.insert_wine_composition(connection, cod_vino, wine.composicion)
            dao.replace_wine_pairings(connection, cod_vino, wine.maridajes)
            result = dao.get_wine(connection, cod_vino)
        return result

    @app.put("/vinos/{cod_vino}", tags=["Vinos"])
    def update_wine(
        cod_vino: PositivePathId,
        wine: WineInput,
        connection: ConnectionDependency,
    ) -> Any:
        with connection.transaction():
            updated = dao.update_wine(connection, cod_vino, wine)
            if updated is None:
                raise HTTPException(status_code=404, detail="No existe el vino solicitado.")
            dao.replace_wine_composition(connection, cod_vino, wine.composicion)
            dao.replace_wine_pairings(connection, cod_vino, wine.maridajes)
            result = dao.get_wine(connection, cod_vino)
        return result

    @app.delete("/vinos/{cod_vino}", tags=["Vinos"])
    def delete_wine(
        cod_vino: PositivePathId, connection: ConnectionDependency
    ) -> dict[str, Any]:
        deleted = dao.delete_wine(connection, cod_vino)
        if deleted is None:
            raise HTTPException(status_code=404, detail="No existe el vino solicitado.")
        return {"eliminado": True, "cod_vino": cod_vino}

    @app.get("/clientes", tags=["Clientes"])
    def list_clients(
        connection: ConnectionDependency,
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
        offset: Annotated[int, Query(ge=0)] = 0,
    ) -> dict[str, Any]:
        return {
            "items": dao.list_clients(connection, limit, offset),
            "limit": limit,
            "offset": offset,
        }

    @app.get("/clientes/{id_cliente}", tags=["Clientes"])
    def get_client(
        id_cliente: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        client = dao.get_client(connection, id_cliente)
        if client is None:
            raise HTTPException(status_code=404, detail="No existe el cliente solicitado.")
        return client

    @app.post("/clientes", status_code=201, tags=["Clientes"])
    def create_client(
        client: ClientInput, connection: ConnectionDependency
    ) -> Any:
        with connection.transaction():
            created = dao.insert_client(connection, client)
            dao.insert_client_subtype(connection, created["id_cliente"], client)
            result = dao.get_client(connection, created["id_cliente"])
        return result

    @app.put("/clientes/{id_cliente}", tags=["Clientes"])
    def update_client(
        id_cliente: PositivePathId,
        client: ClientInput,
        connection: ConnectionDependency,
    ) -> Any:
        with connection.transaction():
            updated = dao.update_client(connection, id_cliente, client)
            if updated is None:
                raise HTTPException(status_code=404, detail="No existe el cliente solicitado.")
            dao.delete_client_subtypes(connection, id_cliente)
            dao.insert_client_subtype(connection, id_cliente, client)
            result = dao.get_client(connection, id_cliente)
        return result

    @app.delete("/clientes/{id_cliente}", tags=["Clientes"])
    def delete_client(
        id_cliente: PositivePathId, connection: ConnectionDependency
    ) -> dict[str, Any]:
        deleted = dao.delete_client(connection, id_cliente)
        if deleted is None:
            raise HTTPException(status_code=404, detail="No existe el cliente solicitado.")
        return {"eliminado": True, "id_cliente": id_cliente}

    @app.post("/comprobantes", status_code=201, tags=["Comprobantes"])
    def create_receipt(
        receipt: ReceiptInput, connection: ConnectionDependency
    ) -> Any:
        with connection.transaction():
            created = dao.insert_receipt(
                connection, receipt.id_cliente, receipt.id_sala
            )
            nro_comprobante = created["nro_comprobante"]
            for line in receipt.renglones:
                inserted = dao.insert_receipt_line(connection, nro_comprobante, line)
                if inserted is None:
                    raise HTTPException(
                        status_code=404,
                        detail=f"No existe el vino {line.cod_vino}.",
                    )
            result = dao.get_receipt(connection, nro_comprobante)
        return result

    @app.get("/comprobantes/{nro_comprobante}", tags=["Comprobantes"])
    def get_receipt(
        nro_comprobante: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        receipt = dao.get_receipt(connection, nro_comprobante)
        if receipt is None:
            raise HTTPException(
                status_code=404, detail="No existe el comprobante solicitado."
            )
        return receipt

    @app.post("/transferencias", status_code=201, tags=["Transferencias"])
    def create_transfer(
        transfer: TransferInput, connection: ConnectionDependency
    ) -> Any:
        return dao.insert_transfer(connection, transfer.id_sala_solicitante)

    @app.post(
        "/transferencias/{nro_transferencia}/renglones",
        status_code=201,
        tags=["Transferencias"],
    )
    def add_transfer_line(
        nro_transferencia: PositivePathId,
        line: DocumentLineInput,
        connection: ConnectionDependency,
    ) -> Any:
        result = dao.insert_transfer_line(connection, nro_transferencia, line)
        if result is None:
            raise HTTPException(
                status_code=404, detail="No existe la transferencia solicitada."
            )
        return result

    @app.post(
        "/transferencias/{nro_transferencia}/terminar",
        tags=["Transferencias"],
    )
    def finish_transfer(
        nro_transferencia: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        result = dao.finish_transfer(connection, nro_transferencia)
        if result is None:
            raise HTTPException(
                status_code=404, detail="No existe la transferencia solicitada."
            )
        return result

    @app.post(
        "/transferencias/{nro_transferencia}/procesar",
        tags=["Transferencias"],
    )
    def process_transfer(
        nro_transferencia: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        with connection.transaction():
            result = dao.process_transfer(connection, nro_transferencia)
            if result is None:
                raise HTTPException(
                    status_code=404, detail="No existe la transferencia solicitada."
                )
        return result

    @app.post("/ingresos", status_code=201, tags=["Ingresos"])
    def create_ingress(
        ingress: IngressInput, connection: ConnectionDependency
    ) -> Any:
        return dao.insert_ingress(
            connection, ingress.cod_transportista, ingress.cuit_bodega
        )

    @app.post(
        "/ingresos/{cod_ingreso}/renglones",
        status_code=201,
        tags=["Ingresos"],
    )
    def add_ingress_line(
        cod_ingreso: PositivePathId,
        line: DocumentLineInput,
        connection: ConnectionDependency,
    ) -> Any:
        result = dao.insert_ingress_line(connection, cod_ingreso, line)
        if result is None:
            raise HTTPException(status_code=404, detail="No existe el ingreso solicitado.")
        return result

    @app.post("/ingresos/{cod_ingreso}/terminar", tags=["Ingresos"])
    def finish_ingress(
        cod_ingreso: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        result = dao.finish_ingress(connection, cod_ingreso)
        if result is None:
            raise HTTPException(status_code=404, detail="No existe el ingreso solicitado.")
        return result

    @app.post("/ingresos/{cod_ingreso}/procesar", tags=["Ingresos"])
    def process_ingress(
        cod_ingreso: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        with connection.transaction():
            result = dao.process_ingress(connection, cod_ingreso)
            if result is None:
                raise HTTPException(status_code=404, detail="No existe el ingreso solicitado.")
        return result

    @app.get("/reportes/top-vinos", tags=["Reportes"])
    def top_wines(
        connection: ConnectionDependency,
        limit: Annotated[int, Query(ge=1, le=100)] = 10,
    ) -> list[Any]:
        return dao.report_top_wines(connection, limit)

    @app.get("/reportes/ventas-por-sala", tags=["Reportes"])
    def sales_by_room(connection: ConnectionDependency) -> list[Any]:
        return dao.report_sales_by_room(connection)

    @app.get("/reportes/vinos-sin-stock", tags=["Reportes"])
    def wines_without_local_stock(
        connection: ConnectionDependency,
        id_sala: Annotated[int, Query(gt=0)],
    ) -> list[Any]:
        return dao.report_wines_without_local_stock(connection, id_sala)

    @app.get("/reportes/transportista-activo", tags=["Reportes"])
    def active_carrier(connection: ConnectionDependency) -> list[Any]:
        return dao.report_active_carrier(connection)

    @app.get("/reportes/trazabilidad/{cod_vino}", tags=["Reportes"])
    def wine_trace(
        cod_vino: PositivePathId, connection: ConnectionDependency
    ) -> Any:
        wine = dao.get_wine(connection, cod_vino)
        if wine is None:
            raise HTTPException(status_code=404, detail="No existe el vino solicitado.")
        return {
            "vino": wine,
            "ingresos": dao.report_wine_income_trace(connection, cod_vino),
            "transferencias": dao.report_wine_transfer_trace(connection, cod_vino),
            "ventas": dao.report_wine_sales_trace(connection, cod_vino),
            "auditoria_precios": dao.report_wine_price_audit(connection, cod_vino),
            "alcance": (
                "La base no vincula vinos con lotes de uva; la trazabilidad "
                "se limita a ingresos, transferencias, ventas y auditoría de precios."
            ),
        }

    return app


app = create_app()
