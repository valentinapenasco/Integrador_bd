from typing import Any

from psycopg import Connection


def _one(connection: Connection, sql: str, params: tuple[Any, ...] = ()) -> Any:
    return connection.execute(sql, params).fetchone()


def _all(connection: Connection, sql: str, params: tuple[Any, ...] = ()) -> list[Any]:
    return connection.execute(sql, params).fetchall()


def check_database(connection: Connection) -> dict[str, int]:
    return _one(connection, "SELECT 1 AS ok")


def list_grape_varieties(connection: Connection) -> list[Any]:
    return _all(
        connection,
        "SELECT id_cepa, nombre, tipo FROM cepa ORDER BY nombre, id_cepa",
    )


def list_pairings(connection: Connection) -> list[Any]:
    return _all(
        connection,
        "SELECT id_maridaje, nombre, temp_servicio FROM maridaje ORDER BY nombre, id_maridaje",
    )


def list_wineries(connection: Connection) -> list[Any]:
    return _all(
        connection,
        "SELECT cuit, razon_social, domicilio FROM bodega ORDER BY razon_social, cuit",
    )


def list_sales_rooms(connection: Connection) -> list[Any]:
    return _all(
        connection,
        """
        SELECT s.id_sala, s.calle, s.numero, s.dia_cierre,
               s.codigo_postal, l.nombre AS localidad
        FROM sala_venta AS s
        JOIN localidad AS l USING (codigo_postal)
        ORDER BY s.id_sala
        """,
    )


def list_wines(
    connection: Connection,
    *,
    tipo: str | None,
    id_cepa: int | None,
    bodega: str | None,
    anada: int | None,
    limit: int,
    offset: int,
) -> list[Any]:
    return _all(
        connection,
        """
        SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml,
               v.graduacion, v.precio, v.cuit_bodega,
               COALESCE(sd.cantidad, 0) + COALESCE(ss.cantidad, 0) AS stock_total
        FROM vino AS v
        JOIN bodega AS b ON b.cuit = v.cuit_bodega
        LEFT JOIN stock_deposito AS sd USING (cod_vino)
        LEFT JOIN (
            SELECT cod_vino, SUM(cantidad)::INT AS cantidad
            FROM stock_sala
            GROUP BY cod_vino
        ) AS ss USING (cod_vino)
        WHERE (%s::tipo_vino IS NULL OR v.tipo = %s::tipo_vino)
          AND (
              %s::INT IS NULL
              OR EXISTS (
                  SELECT 1 FROM composicion AS co
                  WHERE co.cod_vino = v.cod_vino AND co.id_cepa = %s
              )
          )
          AND (%s::TEXT IS NULL OR lower(b.razon_social) = lower(%s))
          AND (%s::INT IS NULL OR v.anada = %s)
        ORDER BY v.cod_vino
        LIMIT %s OFFSET %s
        """,
        (
            tipo,
            tipo,
            id_cepa,
            id_cepa,
            bodega,
            bodega,
            anada,
            anada,
            limit,
            offset,
        ),
    )


def get_wine(connection: Connection, cod_vino: int) -> Any:
    return _one(
        connection,
        """
        SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml,
               v.graduacion, v.precio, v.cuit_bodega,
               b.razon_social AS bodega,
               COALESCE((
                   SELECT jsonb_agg(
                       jsonb_build_object(
                           'id_cepa', ce.id_cepa,
                           'nombre', ce.nombre,
                           'porcentaje', co.porcentaje
                       ) ORDER BY ce.nombre
                   )
                   FROM composicion AS co
                   JOIN cepa AS ce USING (id_cepa)
                   WHERE co.cod_vino = v.cod_vino
               ), '[]'::jsonb) AS cepas,
               COALESCE((
                   SELECT jsonb_agg(
                       jsonb_build_object(
                           'id_maridaje', m.id_maridaje,
                           'nombre', m.nombre,
                           'temp_servicio', m.temp_servicio
                       ) ORDER BY m.nombre
                   )
                   FROM vino_maridaje AS vm
                   JOIN maridaje AS m USING (id_maridaje)
                   WHERE vm.cod_vino = v.cod_vino
               ), '[]'::jsonb) AS maridajes,
               COALESCE(sd.cantidad, 0) + COALESCE(ss.cantidad, 0) AS stock_total
        FROM vino AS v
        JOIN bodega AS b ON b.cuit = v.cuit_bodega
        LEFT JOIN stock_deposito AS sd USING (cod_vino)
        LEFT JOIN (
            SELECT cod_vino, SUM(cantidad)::INT AS cantidad
            FROM stock_sala
            GROUP BY cod_vino
        ) AS ss USING (cod_vino)
        WHERE v.cod_vino = %s
        """,
        (cod_vino,),
    )


def insert_wine(connection: Connection, wine: Any) -> Any:
    return _one(
        connection,
        """
        INSERT INTO vino
            (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING cod_vino
        """,
        (
            wine.nombre,
            wine.tipo,
            wine.anada,
            wine.volumen_ml,
            wine.graduacion,
            wine.precio,
            wine.cuit_bodega,
        ),
    )


def insert_wine_composition(
    connection: Connection, cod_vino: int, composition: list[Any]
) -> None:
    for item in composition:
        connection.execute(
            """
            INSERT INTO composicion (cod_vino, id_cepa, porcentaje)
            VALUES (%s, %s, %s)
            """,
            (cod_vino, item.id_cepa, item.porcentaje),
        )


def replace_wine_composition(
    connection: Connection, cod_vino: int, composition: list[Any]
) -> None:
    connection.execute("DELETE FROM composicion WHERE cod_vino = %s", (cod_vino,))
    insert_wine_composition(connection, cod_vino, composition)


def replace_wine_pairings(
    connection: Connection, cod_vino: int, maridajes: list[int]
) -> None:
    connection.execute("DELETE FROM vino_maridaje WHERE cod_vino = %s", (cod_vino,))
    if maridajes:
        for id_maridaje in maridajes:
            connection.execute(
                """
                INSERT INTO vino_maridaje (cod_vino, id_maridaje)
                VALUES (%s, %s)
                """,
                (cod_vino, id_maridaje),
            )


def update_wine(connection: Connection, cod_vino: int, wine: Any) -> Any:
    return _one(
        connection,
        """
        UPDATE vino
        SET nombre = %s, tipo = %s, anada = %s, volumen_ml = %s,
            graduacion = %s, precio = %s, cuit_bodega = %s
        WHERE cod_vino = %s
        RETURNING cod_vino
        """,
        (
            wine.nombre,
            wine.tipo,
            wine.anada,
            wine.volumen_ml,
            wine.graduacion,
            wine.precio,
            wine.cuit_bodega,
            cod_vino,
        ),
    )


def delete_wine(connection: Connection, cod_vino: int) -> Any:
    return _one(
        connection,
        "DELETE FROM vino WHERE cod_vino = %s RETURNING cod_vino",
        (cod_vino,),
    )


def _client_select() -> str:
    return """
        SELECT c.id_cliente, c.razon_social, c.tipo_doc, c.nro_doc,
               c.direccion, c.localidad, c.fecha_alta, c.tipo_cliente,
               CASE c.tipo_cliente
                   WHEN 'distribuidor' THEN (
                       SELECT jsonb_build_object(
                           'zona_cobertura', d.zona_cobertura,
                           'nro_habilitacion', d.nro_habilitacion
                       )
                       FROM distribuidor AS d WHERE d.id_cliente = c.id_cliente
                   )
                   WHEN 'exportador' THEN (
                       SELECT jsonb_build_object('pais_destino', e.pais_destino)
                       FROM exportador AS e WHERE e.id_cliente = c.id_cliente
                   )
                   ELSE '{}'::jsonb
               END AS datos_especificos
        FROM cliente AS c
    """


def list_clients(connection: Connection, limit: int, offset: int) -> list[Any]:
    return _all(
        connection,
        _client_select() + " ORDER BY c.id_cliente LIMIT %s OFFSET %s",
        (limit, offset),
    )


def get_client(connection: Connection, id_cliente: int) -> Any:
    return _one(
        connection,
        _client_select() + " WHERE c.id_cliente = %s",
        (id_cliente,),
    )


def insert_client(connection: Connection, client: Any) -> Any:
    return _one(
        connection,
        """
        INSERT INTO cliente
            (razon_social, tipo_doc, nro_doc, direccion, localidad, tipo_cliente)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id_cliente
        """,
        (
            client.razon_social,
            client.tipo_doc,
            client.nro_doc,
            client.direccion,
            client.localidad,
            client.tipo_cliente,
        ),
    )


def insert_client_subtype(connection: Connection, id_cliente: int, client: Any) -> None:
    if client.tipo_cliente == "distribuidor":
        connection.execute(
            """
            INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion)
            VALUES (%s, %s, %s)
            """,
            (id_cliente, client.zona_cobertura, client.nro_habilitacion),
        )
    elif client.tipo_cliente == "exportador":
        connection.execute(
            """
            INSERT INTO exportador (id_cliente, pais_destino)
            VALUES (%s, %s)
            """,
            (id_cliente, client.pais_destino),
        )


def update_client(connection: Connection, id_cliente: int, client: Any) -> Any:
    return _one(
        connection,
        """
        UPDATE cliente
        SET razon_social = %s, tipo_doc = %s, nro_doc = %s, direccion = %s,
            localidad = %s, tipo_cliente = %s
        WHERE id_cliente = %s
        RETURNING id_cliente
        """,
        (
            client.razon_social,
            client.tipo_doc,
            client.nro_doc,
            client.direccion,
            client.localidad,
            client.tipo_cliente,
            id_cliente,
        ),
    )


def delete_client_subtypes(connection: Connection, id_cliente: int) -> None:
    connection.execute("DELETE FROM distribuidor WHERE id_cliente = %s", (id_cliente,))
    connection.execute("DELETE FROM exportador WHERE id_cliente = %s", (id_cliente,))


def delete_client(connection: Connection, id_cliente: int) -> Any:
    return _one(
        connection,
        "DELETE FROM cliente WHERE id_cliente = %s RETURNING id_cliente",
        (id_cliente,),
    )


def insert_receipt(connection: Connection, id_cliente: int, id_sala: int) -> Any:
    return _one(
        connection,
        """
        INSERT INTO comprobante (id_cliente, id_sala)
        VALUES (%s, %s)
        RETURNING nro_comprobante
        """,
        (id_cliente, id_sala),
    )


def insert_receipt_line(
    connection: Connection, nro_comprobante: int, line: Any
) -> Any:
    return _one(
        connection,
        """
        INSERT INTO renglon_comprobante
            (nro_comprobante, cod_vino, cantidad, precio_unitario)
        SELECT %s, v.cod_vino, %s, v.precio
        FROM vino AS v
        WHERE v.cod_vino = %s
        RETURNING nro_comprobante, cod_vino, cantidad, precio_unitario
        """,
        (nro_comprobante, line.cantidad, line.cod_vino),
    )


def get_receipt(connection: Connection, nro_comprobante: int) -> Any:
    return _one(
        connection,
        """
        SELECT c.nro_comprobante, c.fecha, c.id_cliente, c.id_sala,
               fn_total_comprobante(c.nro_comprobante) AS total,
               COALESCE((
                   SELECT jsonb_agg(
                       jsonb_build_object(
                           'cod_vino', rc.cod_vino,
                           'cantidad', rc.cantidad,
                           'precio_unitario', rc.precio_unitario
                       ) ORDER BY rc.cod_vino
                   )
                   FROM renglon_comprobante AS rc
                   WHERE rc.nro_comprobante = c.nro_comprobante
               ), '[]'::jsonb) AS renglones
        FROM comprobante AS c
        WHERE c.nro_comprobante = %s
        """,
        (nro_comprobante,),
    )


def insert_transfer(connection: Connection, id_sala: int) -> Any:
    return _one(
        connection,
        """
        INSERT INTO transferencia (id_sala_solicitante)
        VALUES (%s)
        RETURNING nro_transferencia, fecha_confeccion, estado, id_sala_solicitante
        """,
        (id_sala,),
    )


def insert_transfer_line(
    connection: Connection, nro_transferencia: int, line: Any
) -> Any:
    return _one(
        connection,
        """
        INSERT INTO renglon_transferencia (nro_transferencia, cod_vino, cantidad)
        VALUES (%s, %s, %s)
        RETURNING nro_transferencia, cod_vino, cantidad
        """,
        (nro_transferencia, line.cod_vino, line.cantidad),
    )


def finish_transfer(connection: Connection, nro_transferencia: int) -> Any:
    return _one(
        connection,
        """
        UPDATE transferencia SET estado = 'terminado'
        WHERE nro_transferencia = %s
        RETURNING nro_transferencia, fecha_confeccion, estado, id_sala_solicitante
        """,
        (nro_transferencia,),
    )


def process_transfer(connection: Connection, nro_transferencia: int) -> Any:
    connection.execute("CALL sp_procesar_transferencia(%s)", (nro_transferencia,))
    return _one(
        connection,
        """
        SELECT nro_transferencia, fecha_confeccion, estado, id_sala_solicitante
        FROM transferencia
        WHERE nro_transferencia = %s
        """,
        (nro_transferencia,),
    )


def insert_ingress(connection: Connection, cod_transportista: int, cuit_bodega: str) -> Any:
    return _one(
        connection,
        """
        INSERT INTO ingreso (cod_transportista, cuit_bodega)
        VALUES (%s, %s)
        RETURNING cod_ingreso, fecha, estado, cod_transportista, cuit_bodega
        """,
        (cod_transportista, cuit_bodega),
    )


def insert_ingress_line(connection: Connection, cod_ingreso: int, line: Any) -> Any:
    return _one(
        connection,
        """
        INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
        VALUES (%s, %s, %s)
        RETURNING cod_ingreso, cod_vino, cantidad
        """,
        (cod_ingreso, line.cod_vino, line.cantidad),
    )


def finish_ingress(connection: Connection, cod_ingreso: int) -> Any:
    return _one(
        connection,
        """
        UPDATE ingreso SET estado = 'terminado'
        WHERE cod_ingreso = %s
        RETURNING cod_ingreso, fecha, estado, cod_transportista, cuit_bodega
        """,
        (cod_ingreso,),
    )


def process_ingress(connection: Connection, cod_ingreso: int) -> Any:
    connection.execute("CALL sp_procesar_ingreso(%s)", (cod_ingreso,))
    return _one(
        connection,
        """
        SELECT cod_ingreso, fecha, estado, cod_transportista, cuit_bodega
        FROM ingreso
        WHERE cod_ingreso = %s
        """,
        (cod_ingreso,),
    )


def report_top_wines(connection: Connection, limit: int) -> list[Any]:
    return _all(
        connection,
        """
        SELECT v.cod_vino, v.nombre,
               SUM(rc.cantidad)::BIGINT AS botellas_vendidas,
               RANK() OVER (ORDER BY SUM(rc.cantidad) DESC) AS ranking
        FROM vino AS v
        JOIN renglon_comprobante AS rc USING (cod_vino)
        GROUP BY v.cod_vino, v.nombre
        ORDER BY botellas_vendidas DESC, v.cod_vino
        LIMIT %s
        """,
        (limit,),
    )


def report_sales_by_room(connection: Connection) -> list[Any]:
    return _all(
        connection,
        """
        WITH ventas_por_sala AS (
            SELECT c.id_sala,
                   SUM(fn_total_comprobante(c.nro_comprobante))::NUMERIC(14,2)
                       AS monto_neto
            FROM comprobante AS c
            WHERE c.fecha >= CURRENT_DATE - INTERVAL '3 months'
              AND c.fecha < CURRENT_DATE + INTERVAL '1 day'
            GROUP BY c.id_sala
        )
        SELECT s.id_sala, l.nombre AS localidad,
               COALESCE(vps.monto_neto, 0)::NUMERIC(14,2) AS monto_neto
        FROM sala_venta AS s
        JOIN localidad AS l USING (codigo_postal)
        LEFT JOIN ventas_por_sala AS vps USING (id_sala)
        ORDER BY monto_neto DESC, s.id_sala
        """,
    )


def report_wines_without_local_stock(
    connection: Connection, id_sala: int
) -> list[Any]:
    return _all(
        connection,
        """
        SELECT v.cod_vino, v.nombre,
               COALESCE(ss.cantidad, 0) AS stock_sala,
               COALESCE(sd.cantidad, 0) AS stock_deposito
        FROM vino AS v
        JOIN stock_deposito AS sd USING (cod_vino)
        LEFT JOIN stock_sala AS ss
          ON ss.cod_vino = v.cod_vino AND ss.id_sala = %s
        WHERE COALESCE(ss.cantidad, 0) = 0 AND sd.cantidad > 0
        ORDER BY v.cod_vino
        """,
        (id_sala,),
    )


def report_active_carrier(connection: Connection) -> list[Any]:
    return _all(
        connection,
        """
        WITH actividad AS (
            SELECT t.cod_transportista, t.razon_social,
                   COUNT(i.cod_ingreso)::BIGINT AS ingresos
            FROM transportista AS t
            LEFT JOIN ingreso AS i
              ON i.cod_transportista = t.cod_transportista
             AND i.fecha >= CURRENT_DATE - INTERVAL '1 month'
             AND i.fecha < CURRENT_DATE + INTERVAL '1 day'
            GROUP BY t.cod_transportista, t.razon_social
        ),
        ranking AS (
            SELECT actividad.*,
                   RANK() OVER (ORDER BY ingresos DESC) AS posicion
            FROM actividad
        )
        SELECT cod_transportista, razon_social, ingresos
        FROM ranking
        WHERE posicion = 1
        ORDER BY cod_transportista
        """,
    )


def report_wine_income_trace(connection: Connection, cod_vino: int) -> list[Any]:
    return _all(
        connection,
        """
        SELECT i.cod_ingreso, i.fecha, i.estado, i.cuit_bodega,
               i.cod_transportista, ri.cantidad
        FROM renglon_ingreso AS ri
        JOIN ingreso AS i USING (cod_ingreso)
        WHERE ri.cod_vino = %s
        ORDER BY i.fecha, i.cod_ingreso
        """,
        (cod_vino,),
    )


def report_wine_transfer_trace(connection: Connection, cod_vino: int) -> list[Any]:
    return _all(
        connection,
        """
        SELECT t.nro_transferencia, t.fecha_confeccion, t.estado,
               t.id_sala_solicitante, rt.cantidad
        FROM renglon_transferencia AS rt
        JOIN transferencia AS t USING (nro_transferencia)
        WHERE rt.cod_vino = %s
        ORDER BY t.fecha_confeccion, t.nro_transferencia
        """,
        (cod_vino,),
    )


def report_wine_sales_trace(connection: Connection, cod_vino: int) -> list[Any]:
    return _all(
        connection,
        """
        SELECT c.nro_comprobante, c.fecha, c.id_cliente, c.id_sala,
               rc.cantidad, rc.precio_unitario
        FROM renglon_comprobante AS rc
        JOIN comprobante AS c USING (nro_comprobante)
        WHERE rc.cod_vino = %s
        ORDER BY c.fecha, c.nro_comprobante
        """,
        (cod_vino,),
    )


def report_wine_price_audit(connection: Connection, cod_vino: int) -> list[Any]:
    return _all(
        connection,
        """
        SELECT precio_anterior, precio_nuevo, fecha_hora, usuario
        FROM auditoria_precio
        WHERE cod_vino = %s
        ORDER BY fecha_hora, id_auditoria
        """,
        (cod_vino,),
    )
