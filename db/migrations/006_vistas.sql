CREATE OR REPLACE VIEW vw_stock_total_vino AS
SELECT
    v.cod_vino,
    v.nombre,
    COALESCE(sd.cantidad, 0) AS stock_deposito,
    COALESCE(ss.cantidad, 0) AS stock_salas,
    COALESCE(sd.cantidad, 0) + COALESCE(ss.cantidad, 0) AS stock_total
FROM vino AS v
LEFT JOIN stock_deposito AS sd ON sd.cod_vino = v.cod_vino
LEFT JOIN (
    SELECT cod_vino, SUM(cantidad)::INT AS cantidad
    FROM stock_sala
    GROUP BY cod_vino
) AS ss ON ss.cod_vino = v.cod_vino;

CREATE OR REPLACE VIEW vw_ventas_mensuales_sala AS
SELECT
    c.id_sala,
    date_trunc('month', c.fecha)::DATE AS mes,
    COUNT(DISTINCT c.nro_comprobante)::INT AS comprobantes,
    SUM(rc.cantidad)::INT AS unidades,
    SUM(rc.cantidad * rc.precio_unitario)::NUMERIC(12,2) AS importe_bruto,
    SUM(
        rc.cantidad * rc.precio_unitario
        * (1 - fn_descuento_cliente(c.id_cliente))
    )::NUMERIC(12,2) AS importe_neto
FROM comprobante AS c
JOIN renglon_comprobante AS rc
  ON rc.nro_comprobante = c.nro_comprobante
GROUP BY c.id_sala, date_trunc('month', c.fecha)::DATE;

CREATE OR REPLACE VIEW vw_documentos_pendientes AS
SELECT
    'ingreso'::TEXT AS tipo_documento,
    i.cod_ingreso::TEXT AS identificador,
    i.fecha,
    i.estado::TEXT,
    i.cuit_bodega::TEXT AS referencia
FROM ingreso AS i
WHERE i.estado <> 'procesado'
UNION ALL
SELECT
    'transferencia'::TEXT,
    t.nro_transferencia::TEXT,
    t.fecha_confeccion,
    t.estado::TEXT,
    t.id_sala_solicitante::TEXT
FROM transferencia AS t
WHERE t.estado <> 'procesado';
