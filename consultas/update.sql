\set ON_ERROR_STOP on

-- U1. Recalcular el total de todos los comprobantes aplicando el descuento
-- correspondiente al cliente. comprobante no almacena un total: se informa
-- el total calculado, sin alterar el esquema ni los renglones históricos.
-- Para exportadores con más de 3 permisos se muestra el 35% indicado en U6.
WITH exportadores_35 AS (
    SELECT pe.id_cliente_exportador AS id_cliente
    FROM permiso_exportacion AS pe
    GROUP BY pe.id_cliente_exportador
    HAVING COUNT(*) > 3
),
subtotales AS (
    SELECT c.nro_comprobante,
           c.id_cliente,
           COALESCE(SUM(rc.cantidad * rc.precio_unitario), 0) AS subtotal
    FROM comprobante AS c
    LEFT JOIN renglon_comprobante AS rc
      ON rc.nro_comprobante = c.nro_comprobante
    GROUP BY c.nro_comprobante, c.id_cliente
)
SELECT s.nro_comprobante,
       s.id_cliente,
       CASE
           WHEN e.id_cliente IS NOT NULL
               THEN ROUND(s.subtotal * 0.65, 2)
           ELSE fn_total_comprobante(s.nro_comprobante)
       END AS total_recalculado
FROM subtotales AS s
LEFT JOIN exportadores_35 AS e ON e.id_cliente = s.id_cliente
ORDER BY s.nro_comprobante;

-- U2. Aumentar un 20% el salario de los empleados con más de 5 años.
-- El filtro usa la función de antigüedad y el cambio queda limitado a esta
-- transacción de demostración.
BEGIN;
SELECT cuit, salario, fn_antiguedad_anios(fecha_ingreso) AS antiguedad_anios
FROM empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5
ORDER BY cuit;

UPDATE empleado
SET salario = ROUND(salario * 1.20, 2)
WHERE fn_antiguedad_anios(fecha_ingreso) > 5
RETURNING cuit, salario;

SELECT cuit, salario, fn_antiguedad_anios(fecha_ingreso) AS antiguedad_anios
FROM empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5
ORDER BY cuit;
ROLLBACK;

-- U3. Incrementar un 13% el precio de los vinos de la bodega 20000000001.
-- Cambiar el CUIT del filtro si se desea probar otra bodega del dataset.
BEGIN;
SELECT cod_vino, nombre, precio
FROM vino
WHERE cuit_bodega = '20000000001'
ORDER BY cod_vino;

UPDATE vino
SET precio = ROUND(precio * 1.13, 2)
WHERE cuit_bodega = '20000000001'
RETURNING cod_vino, nombre, precio;

-- El trigger de auditoría agrega una fila por precio realmente modificado.
SELECT v.cod_vino, v.nombre, v.precio,
       COUNT(ap.id_auditoria) AS auditorias_de_precio
FROM vino AS v
LEFT JOIN auditoria_precio AS ap ON ap.cod_vino = v.cod_vino
WHERE v.cuit_bodega = '20000000001'
GROUP BY v.cod_vino, v.nombre, v.precio
ORDER BY v.cod_vino;
ROLLBACK;

-- U4. Intercambiar lunes y miércoles como día de cierre en una sentencia.
BEGIN;
SELECT id_sala, dia_cierre
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miércoles')
ORDER BY id_sala;

UPDATE sala_venta
SET dia_cierre = CASE dia_cierre
    WHEN 'lunes' THEN 'miércoles'
    WHEN 'miércoles' THEN 'lunes'
END
WHERE dia_cierre IN ('lunes', 'miércoles')
RETURNING id_sala, dia_cierre;

SELECT id_sala, dia_cierre
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miércoles')
ORDER BY id_sala;
ROLLBACK;

-- U5. Descontar 15% a los 10 vinos menos vendidos de toda la red.
-- Los vinos sin ventas quedan con cero unidades y se ordenan por código.
BEGIN;
WITH ventas AS (
    SELECT cod_vino, SUM(cantidad)::BIGINT AS botellas_vendidas
    FROM renglon_comprobante
    GROUP BY cod_vino
)
SELECT v.cod_vino, v.nombre, v.precio,
       COALESCE(ventas.botellas_vendidas, 0) AS botellas_vendidas
FROM vino AS v
LEFT JOIN ventas ON ventas.cod_vino = v.cod_vino
ORDER BY COALESCE(ventas.botellas_vendidas, 0), v.cod_vino
LIMIT 10;

WITH ventas AS (
    SELECT cod_vino, SUM(cantidad)::BIGINT AS botellas_vendidas
    FROM renglon_comprobante
    GROUP BY cod_vino
),
menos_vendidos AS (
    SELECT v.cod_vino
    FROM vino AS v
    LEFT JOIN ventas ON ventas.cod_vino = v.cod_vino
    ORDER BY COALESCE(ventas.botellas_vendidas, 0), v.cod_vino
    LIMIT 10
)
UPDATE vino AS v
SET precio = ROUND(v.precio * 0.85, 2)
FROM menos_vendidos AS mv
WHERE mv.cod_vino = v.cod_vino
RETURNING v.cod_vino, v.nombre, v.precio;

WITH ventas AS (
    SELECT cod_vino, SUM(cantidad)::BIGINT AS botellas_vendidas
    FROM renglon_comprobante
    GROUP BY cod_vino
),
menos_vendidos AS (
    SELECT v.cod_vino
    FROM vino AS v
    LEFT JOIN ventas ON ventas.cod_vino = v.cod_vino
    ORDER BY COALESCE(ventas.botellas_vendidas, 0), v.cod_vino
    LIMIT 10
)
SELECT v.cod_vino, v.nombre, v.precio,
       COUNT(ap.id_auditoria) AS auditorias_de_precio
FROM vino AS v
JOIN menos_vendidos AS mv USING (cod_vino)
LEFT JOIN auditoria_precio AS ap ON ap.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre, v.precio
ORDER BY v.cod_vino;
ROLLBACK;

-- U6. Calcular el 35% para exportadores con más de 3 permisos.
-- No existe una columna de descuento persistido: se informa el valor
-- aplicable sin cambiar fn_descuento_cliente ni agregar columnas al esquema.
SELECT c.id_cliente, c.razon_social,
       COUNT(pe.cod_permiso) AS permisos,
       0.35::NUMERIC(5,4) AS descuento_calculado
FROM cliente AS c
JOIN exportador AS e ON e.id_cliente = c.id_cliente
JOIN permiso_exportacion AS pe
  ON pe.id_cliente_exportador = e.id_cliente
GROUP BY c.id_cliente, c.razon_social
HAVING COUNT(pe.cod_permiso) > 3
ORDER BY c.id_cliente;
