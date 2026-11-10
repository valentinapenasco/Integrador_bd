\set ON_ERROR_STOP on

-- S1. Ranking de los 10 vinos con más botellas vendidas en toda la red.
SELECT v.cod_vino, v.nombre, SUM(rc.cantidad)::BIGINT AS botellas_vendidas,
       RANK() OVER (ORDER BY SUM(rc.cantidad) DESC) AS ranking
FROM vino AS v
JOIN renglon_comprobante AS rc USING (cod_vino)
GROUP BY v.cod_vino, v.nombre
ORDER BY botellas_vendidas DESC, v.cod_vino
LIMIT 10;

-- S2. Vinos vendidos en todas las salas (división relacional mediante doble
-- NOT EXISTS). Se evita el resultado vacuo cuando todavía no hay salas.
SELECT v.cod_vino, v.nombre
FROM vino AS v
WHERE EXISTS (SELECT 1 FROM sala_venta)
  AND NOT EXISTS (
      SELECT 1
      FROM sala_venta AS s
      WHERE NOT EXISTS (
          SELECT 1
          FROM comprobante AS c
          JOIN renglon_comprobante AS rc
            ON rc.nro_comprobante = c.nro_comprobante
          WHERE c.id_sala = s.id_sala
            AND rc.cod_vino = v.cod_vino
      )
  )
ORDER BY v.cod_vino;

-- S3. Cantidad de clientes de cada tipo que compraron en la sala 1 durante
-- los últimos 7 días; cambiar el ID para otra sala.
SELECT cl.tipo_cliente,
       COUNT(DISTINCT ventas.id_cliente) AS clientes_compradores
FROM cliente AS cl
LEFT JOIN (
    SELECT DISTINCT c.id_cliente
    FROM comprobante AS c
    WHERE c.id_sala = 1
      AND c.fecha >= CURRENT_DATE - INTERVAL '7 days'
      AND c.fecha < CURRENT_DATE + INTERVAL '1 day'
) AS ventas ON ventas.id_cliente = cl.id_cliente
GROUP BY cl.tipo_cliente
ORDER BY cl.tipo_cliente;

-- S4. Top 5 de salas por unidades solicitadas del vino 1 en transferencias
-- de los últimos 15 días; cambiar el código del vino.
SELECT s.id_sala, l.nombre AS localidad, SUM(rt.cantidad)::BIGINT AS unidades
FROM transferencia AS t
JOIN renglon_transferencia AS rt USING (nro_transferencia)
JOIN sala_venta AS s ON s.id_sala = t.id_sala_solicitante
JOIN localidad AS l USING (codigo_postal)
WHERE rt.cod_vino = 1
  AND t.fecha_confeccion >= CURRENT_DATE - INTERVAL '15 days'
  AND t.fecha_confeccion < CURRENT_DATE + INTERVAL '1 day'
GROUP BY s.id_sala, l.nombre
ORDER BY unidades DESC, s.id_sala
LIMIT 5;

-- S5. Salas que empatan con la menor cantidad de transferencias pendientes.
WITH pendientes_por_sala AS (
    SELECT s.id_sala, l.nombre AS localidad,
           COUNT(t.nro_transferencia)::BIGINT AS pendientes
    FROM sala_venta AS s
    JOIN localidad AS l USING (codigo_postal)
    LEFT JOIN transferencia AS t
      ON t.id_sala_solicitante = s.id_sala
     AND t.estado <> 'procesado'
    GROUP BY s.id_sala, l.nombre
)
SELECT id_sala, localidad, pendientes
FROM pendientes_por_sala
WHERE pendientes = (SELECT MIN(pendientes) FROM pendientes_por_sala)
ORDER BY id_sala;

-- S6. Para la sala 1, vinos sin stock local pero con stock en el depósito.
-- Cambiar el ID para consultar otra sala.
SELECT v.cod_vino, v.nombre, COALESCE(sd.cantidad, 0) AS stock_deposito
FROM vino AS v
JOIN stock_deposito AS sd USING (cod_vino)
LEFT JOIN stock_sala AS ss
  ON ss.cod_vino = v.cod_vino
 AND ss.id_sala = 1
WHERE COALESCE(ss.cantidad, 0) = 0
  AND sd.cantidad > 0
ORDER BY v.cod_vino;

-- S7. Transportista con mayor cantidad de ingresos en el último mes móvil.
-- Se muestran todos los empates en el máximo.
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
ORDER BY cod_transportista;

-- S8. Monto neto vendido por sala en los últimos 3 meses móviles.
-- Se incluyen salas sin ventas, ordenadas con monto cero.
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
ORDER BY monto_neto DESC, s.id_sala;

-- S9. Ficha del vino 1: cepas, porcentajes, bodega, maridajes y stock total.
-- Cambiar el código para consultar otro vino. Las agregaciones separadas
-- evitan multiplicar filas entre cepas y maridajes.
WITH ficha_cepas AS (
    SELECT co.cod_vino,
           STRING_AGG(
               FORMAT('%s (%s%%)', ce.nombre, co.porcentaje),
               ', ' ORDER BY ce.nombre
           ) AS cepas
    FROM composicion AS co
    JOIN cepa AS ce USING (id_cepa)
    GROUP BY co.cod_vino
),
ficha_maridajes AS (
    SELECT vm.cod_vino,
           STRING_AGG(m.nombre, ', ' ORDER BY m.nombre) AS maridajes
    FROM vino_maridaje AS vm
    JOIN maridaje AS m USING (id_maridaje)
    GROUP BY vm.cod_vino
)
SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml,
       fc.cepas, b.razon_social AS bodega,
       fm.maridajes,
       COALESCE(st.stock_total, 0) AS stock_total
FROM vino AS v
JOIN bodega AS b ON b.cuit = v.cuit_bodega
LEFT JOIN ficha_cepas AS fc USING (cod_vino)
LEFT JOIN ficha_maridajes AS fm USING (cod_vino)
LEFT JOIN vw_stock_total_vino AS st USING (cod_vino)
WHERE v.cod_vino = 1;

-- S10. Rendimiento (kg/ha) por parcela y campaña y comparación con el
-- promedio de su finca en esa campaña. La subconsulta correlacionada calcula
-- el promedio entre los rendimientos de las parcelas de la misma finca.
WITH rendimientos AS (
    SELECT f.id_finca, f.nombre AS finca, p.nro_parcela,
           lu.anio_campana,
           lu.kilos / NULLIF(p.superficie, 0) AS kg_por_ha
    FROM lote_uva AS lu
    JOIN parcela AS p
      ON p.id_finca = lu.id_finca
     AND p.nro_parcela = lu.nro_parcela
    JOIN finca AS f ON f.id_finca = p.id_finca
)
SELECT r.id_finca, r.finca, r.nro_parcela, r.anio_campana,
       ROUND(r.kg_por_ha, 2) AS kg_por_ha,
       ROUND((
           SELECT AVG(otra.kg_por_ha)
           FROM rendimientos AS otra
           WHERE otra.id_finca = r.id_finca
             AND otra.anio_campana = r.anio_campana
       ), 2) AS promedio_finca_campana,
       r.kg_por_ha < (
           SELECT AVG(otra.kg_por_ha)
           FROM rendimientos AS otra
           WHERE otra.id_finca = r.id_finca
             AND otra.anio_campana = r.anio_campana
       ) AS debajo_del_promedio
FROM rendimientos AS r
ORDER BY r.id_finca, r.anio_campana, r.nro_parcela;

-- S11. Ranking mensual de vinos dentro de cada sala y ventas acumuladas por
-- sala a lo largo de los meses. La ventana se calcula sobre totales mensuales
-- (no sobre las filas individuales de cada vino).
WITH ventas_vino_mes AS (
    SELECT c.id_sala,
           DATE_TRUNC('month', c.fecha)::DATE AS mes,
           rc.cod_vino,
           v.nombre AS vino,
           SUM(rc.cantidad)::BIGINT AS botellas,
           SUM(
               rc.cantidad * rc.precio_unitario
               * (1 - fn_descuento_cliente(c.id_cliente))
           )::NUMERIC(14,2) AS importe_neto
    FROM comprobante AS c
    JOIN renglon_comprobante AS rc USING (nro_comprobante)
    JOIN vino AS v USING (cod_vino)
    GROUP BY c.id_sala, DATE_TRUNC('month', c.fecha)::DATE,
             rc.cod_vino, v.nombre
),
ranking_mensual AS (
    SELECT ventas_vino_mes.*,
           RANK() OVER (
               PARTITION BY id_sala, mes
               ORDER BY botellas DESC
           ) AS ranking_vino
    FROM ventas_vino_mes
),
totales_mensuales AS (
    SELECT id_sala, mes, SUM(importe_neto)::NUMERIC(14,2) AS total_mes
    FROM ventas_vino_mes
    GROUP BY id_sala, mes
),
acumulados AS (
    SELECT id_sala, mes, total_mes,
           SUM(total_mes) OVER (
               PARTITION BY id_sala
               ORDER BY mes
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           )::NUMERIC(14,2) AS ventas_acumuladas
    FROM totales_mensuales
)
SELECT rm.id_sala, rm.mes, rm.cod_vino, rm.vino, rm.botellas,
       rm.ranking_vino, a.total_mes, a.ventas_acumuladas
FROM ranking_mensual AS rm
JOIN acumulados AS a USING (id_sala, mes)
ORDER BY rm.id_sala, rm.mes, rm.ranking_vino, rm.cod_vino;

-- S12.a. Clientes que compraron todos los vinos de la bodega 20000000001.
-- La doble negación implementa la división relacional con NOT EXISTS.
SELECT cl.id_cliente, cl.razon_social
FROM cliente AS cl
WHERE EXISTS (
    SELECT 1 FROM vino WHERE cuit_bodega = '20000000001'
)
AND NOT EXISTS (
    SELECT 1
    FROM vino AS v
    WHERE v.cuit_bodega = '20000000001'
      AND NOT EXISTS (
          SELECT 1
          FROM comprobante AS c
          JOIN renglon_comprobante AS rc USING (nro_comprobante)
          WHERE c.id_cliente = cl.id_cliente
            AND rc.cod_vino = v.cod_vino
      )
)
ORDER BY cl.id_cliente;

-- S12.b. Clientes que nunca compraron un vino tinto (anti-join con
-- NOT EXISTS). Incluye clientes sin ningún comprobante.
SELECT cl.id_cliente, cl.razon_social
FROM cliente AS cl
WHERE NOT EXISTS (
    SELECT 1
    FROM comprobante AS c
    JOIN renglon_comprobante AS rc USING (nro_comprobante)
    JOIN vino AS v USING (cod_vino)
    WHERE c.id_cliente = cl.id_cliente
      AND v.tipo = 'tinto'
)
ORDER BY cl.id_cliente;
