import os
from collections.abc import Iterator

from fastapi import Request
from psycopg import Connection
from psycopg_pool import ConnectionPool
from psycopg.rows import dict_row


def create_pool() -> ConnectionPool:
    password = os.getenv("DB_PASSWORD")
    if not password or password == "replace_with_locally_configured_role_password":
        raise RuntimeError(
            "Configure DB_PASSWORD with the password assigned to bodegas_api."
        )

    return ConnectionPool(
        conninfo="",
        kwargs={
            "host": os.getenv("DB_HOST", "localhost"),
            "port": int(os.getenv("DB_PORT", "5432")),
            "dbname": os.getenv("DB_NAME", "bodegas_atuel"),
            "user": os.getenv("DB_USER", "bodegas_api"),
            "password": password,
            "sslmode": os.getenv("DB_SSLMODE", "prefer"),
            **(
                {"sslrootcert": os.environ["DB_SSLROOTCERT"]}
                if os.getenv("DB_SSLROOTCERT")
                else {}
            ),
            "row_factory": dict_row,
        },
        min_size=1,
        max_size=int(os.getenv("DB_POOL_MAX_SIZE", "10")),
        open=False,
        name="bodegas-api",
    )


def get_connection(request: Request) -> Iterator[Connection]:
    with request.app.state.pool.connection() as connection:
        yield connection
