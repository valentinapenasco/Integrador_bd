-- Mediciones de la etapa 4.
-- Ejecutar con psql sobre una base cargada:
-- psql "$DATABASE_URL" -f db/performance/medir_etapa4.sql

\timing on
\echo '=== BEFORE: consultas sin indices H4 ==='
DROP INDEX IF EXISTS idx_comprobante_cliente;
DROP INDEX IF EXISTS idx_renglon_comprobante_vino;
DROP INDEX IF EXISTS idx_comprobante_fecha_sala;
DROP INDEX IF EXISTS idx_transferencia_pendiente;
DROP INDEX IF EXISTS idx_comprobante_fecha_brin;
DROP INDEX IF EXISTS idx_bodega_razon_social_lower;
ANALYZE;

\echo '--- Q1: comprobantes de un cliente ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM comprobante
WHERE id_cliente = 1;

\echo '--- Q2: renglones de un vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM renglon_comprobante
WHERE cod_vino = 1;

\echo '--- Q3: comprobantes de una sala y fecha ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM comprobante
WHERE fecha = CURRENT_DATE
  AND id_sala = 1;

\echo '--- S9: ficha de un vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino, v.nombre, SUM(rc.cantidad) AS botellas_vendidas
FROM vino AS v
JOIN renglon_comprobante AS rc ON rc.cod_vino = v.cod_vino
WHERE v.cod_vino = (SELECT MIN(cod_vino) FROM vino)
GROUP BY v.cod_vino, v.nombre;

\echo '--- S1: ventas por vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT rc.cod_vino, SUM(rc.cantidad) AS botellas_vendidas
FROM renglon_comprobante AS rc
GROUP BY rc.cod_vino
ORDER BY botellas_vendidas DESC
LIMIT 10;

\echo '--- S3: ventas por sala y periodo ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_sala, COUNT(*) AS comprobantes
FROM comprobante AS c
WHERE c.fecha >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.id_sala
ORDER BY comprobantes DESC;

\echo '--- S5: transferencias pendientes ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_sala_solicitante, COUNT(*) AS pendientes
FROM transferencia
WHERE estado <> 'procesado'
GROUP BY id_sala_solicitante
ORDER BY pendientes;

\echo '=== AFTER: consultas con indices H4 ==='
CREATE INDEX IF NOT EXISTS idx_comprobante_cliente
    ON comprobante (id_cliente);
CREATE INDEX IF NOT EXISTS idx_renglon_comprobante_vino
    ON renglon_comprobante (cod_vino);
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_sala
    ON comprobante (fecha, id_sala);
CREATE INDEX IF NOT EXISTS idx_transferencia_pendiente
    ON transferencia (id_sala_solicitante, fecha_confeccion)
    WHERE estado <> 'procesado';
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_brin
    ON comprobante USING BRIN (fecha)
    WITH (pages_per_range = 32);
CREATE INDEX IF NOT EXISTS idx_bodega_razon_social_lower
    ON bodega (lower(razon_social));
ANALYZE;

\echo '--- Q1: comprobantes de un cliente ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM comprobante
WHERE id_cliente = 1;

\echo '--- Q2: renglones de un vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM renglon_comprobante
WHERE cod_vino = 1;

\echo '--- Q3: comprobantes de una sala y fecha ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM comprobante
WHERE fecha = CURRENT_DATE
  AND id_sala = 1;

\echo '--- S9: ficha de un vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino, v.nombre, SUM(rc.cantidad) AS botellas_vendidas
FROM vino AS v
JOIN renglon_comprobante AS rc ON rc.cod_vino = v.cod_vino
WHERE v.cod_vino = (SELECT MIN(cod_vino) FROM vino)
GROUP BY v.cod_vino, v.nombre;

\echo '--- S1: ventas por vino ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT rc.cod_vino, SUM(rc.cantidad) AS botellas_vendidas
FROM renglon_comprobante AS rc
GROUP BY rc.cod_vino
ORDER BY botellas_vendidas DESC
LIMIT 10;

\echo '--- S3: ventas por sala y periodo ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_sala, COUNT(*) AS comprobantes
FROM comprobante AS c
WHERE c.fecha >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.id_sala
ORDER BY comprobantes DESC;

\echo '--- S5: transferencias pendientes ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_sala_solicitante, COUNT(*) AS pendientes
FROM transferencia
WHERE estado <> 'procesado'
GROUP BY id_sala_solicitante
ORDER BY pendientes;

\echo '=== COSTO DE ESCRITURA ==='
DROP TABLE IF EXISTS etapa4_medicion_escritura;
CREATE TEMP TABLE etapa4_medicion_escritura AS
SELECT * FROM comprobante WITH NO DATA;
CREATE INDEX etapa4_escritura_cliente
    ON etapa4_medicion_escritura (id_cliente);
CREATE INDEX etapa4_escritura_fecha_sala
    ON etapa4_medicion_escritura (fecha, id_sala);

\echo '--- Escritura con indices activos ---'
\timing on
INSERT INTO etapa4_medicion_escritura
SELECT * FROM comprobante LIMIT 1000;
TRUNCATE etapa4_medicion_escritura;

\echo '--- Escritura sin indices H4 ---'
DROP INDEX etapa4_escritura_cliente;
DROP INDEX etapa4_escritura_fecha_sala;
INSERT INTO etapa4_medicion_escritura
SELECT * FROM comprobante LIMIT 1000;

\echo '=== CASO DE BAJA SELECTIVIDAD ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM comprobante
WHERE fecha >= DATE '2000-01-01';

\echo '=== RESTAURAR INDICES H4 ==='
CREATE INDEX IF NOT EXISTS idx_comprobante_cliente
    ON comprobante (id_cliente);
CREATE INDEX IF NOT EXISTS idx_renglon_comprobante_vino
    ON renglon_comprobante (cod_vino);
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_sala
    ON comprobante (fecha, id_sala);
CREATE INDEX IF NOT EXISTS idx_transferencia_pendiente
    ON transferencia (id_sala_solicitante, fecha_confeccion)
    WHERE estado <> 'procesado';
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_brin
    ON comprobante USING BRIN (fecha)
    WITH (pages_per_range = 32);
CREATE INDEX IF NOT EXISTS idx_bodega_razon_social_lower
    ON bodega (lower(razon_social));

\echo '=== FIN ==='