\set ON_ERROR_STOP on

-- I1. Vincular General Alvear (CP 5603) con el transportista con menos
-- ingresos de los últimos 3 meses; los empates se resuelven por código.
BEGIN;
SELECT t.cod_transportista, t.razon_social,
       COUNT(i.cod_ingreso) AS ingresos_ultimo_trimestre
FROM transportista AS t
LEFT JOIN ingreso AS i
  ON i.cod_transportista = t.cod_transportista
 AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
 AND i.fecha < CURRENT_DATE + INTERVAL '1 day'
GROUP BY t.cod_transportista, t.razon_social
ORDER BY ingresos_ultimo_trimestre, t.cod_transportista
LIMIT 1;
SELECT codigo_postal, nombre
FROM localidad
WHERE codigo_postal = '5603';

INSERT INTO transportista_localidad (cod_transportista, codigo_postal)
SELECT elegido.cod_transportista, '5603'
FROM (
    SELECT t.cod_transportista
    FROM transportista AS t
    LEFT JOIN ingreso AS i
      ON i.cod_transportista = t.cod_transportista
     AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
     AND i.fecha < CURRENT_DATE + INTERVAL '1 day'
    GROUP BY t.cod_transportista
    ORDER BY COUNT(i.cod_ingreso), t.cod_transportista
    LIMIT 1
) AS elegido
WHERE EXISTS (
    SELECT 1 FROM localidad WHERE codigo_postal = '5603'
)
AND NOT EXISTS (
    SELECT 1
    FROM transportista_localidad AS tl
    WHERE tl.cod_transportista = elegido.cod_transportista
      AND tl.codigo_postal = '5603'
)
RETURNING cod_transportista, codigo_postal;

SELECT tl.cod_transportista, t.razon_social, l.codigo_postal, l.nombre
FROM transportista_localidad AS tl
JOIN transportista AS t USING (cod_transportista)
JOIN localidad AS l USING (codigo_postal)
WHERE l.codigo_postal = '5603'
ORDER BY tl.cod_transportista;
ROLLBACK;

-- I2. Crear «cordero al disco» y asociarlo a todos los vinos tintos de 14°
-- o más. Se usa 18° como temperatura de servicio válida; las asociaciones
-- existentes no se duplican.
BEGIN;
SELECT v.cod_vino, v.nombre, v.graduacion
FROM vino AS v
WHERE v.tipo = 'tinto' AND v.graduacion >= 14
ORDER BY v.cod_vino;
SELECT id_maridaje, nombre
FROM maridaje
WHERE nombre = 'cordero al disco'
ORDER BY id_maridaje;

WITH vinos_elegibles AS (
    SELECT cod_vino
    FROM vino
    WHERE tipo = 'tinto' AND graduacion >= 14
),
nuevo_maridaje AS (
    INSERT INTO maridaje (nombre, temp_servicio)
    SELECT 'cordero al disco', 18.0
    WHERE EXISTS (SELECT 1 FROM vinos_elegibles)
      AND NOT EXISTS (
          SELECT 1 FROM maridaje WHERE nombre = 'cordero al disco'
      )
    RETURNING id_maridaje
),
maridaje_objetivo AS (
    SELECT id_maridaje FROM nuevo_maridaje
    UNION ALL
    SELECT m.id_maridaje
    FROM maridaje AS m
    WHERE m.nombre = 'cordero al disco'
      AND NOT EXISTS (SELECT 1 FROM nuevo_maridaje)
    ORDER BY id_maridaje
    LIMIT 1
)
INSERT INTO vino_maridaje (cod_vino, id_maridaje)
SELECT ve.cod_vino, mo.id_maridaje
FROM vinos_elegibles AS ve
CROSS JOIN maridaje_objetivo AS mo
ON CONFLICT (cod_vino, id_maridaje) DO NOTHING
RETURNING cod_vino, id_maridaje;

SELECT v.cod_vino, v.nombre, m.id_maridaje, m.nombre AS maridaje
FROM vino AS v
JOIN vino_maridaje AS vm USING (cod_vino)
JOIN maridaje AS m USING (id_maridaje)
WHERE v.tipo = 'tinto'
  AND v.graduacion >= 14
  AND m.nombre = 'cordero al disco'
ORDER BY v.cod_vino;
ROLLBACK;

-- I3. Crear un comprobante para el cliente 1 en la sala 1 con tres vinos.
-- Cambiar id_cliente si corresponde. El detalle se limita a vinos con stock
-- positivo; el trigger descuenta stock y fn_total_comprobante calcula el total.
BEGIN;
SELECT COUNT(*) AS comprobantes_cliente_sala_antes
FROM comprobante
WHERE id_cliente = 1 AND id_sala = 1;
SELECT ss.cod_vino, v.nombre, ss.cantidad AS stock_antes
FROM stock_sala AS ss
JOIN vino AS v USING (cod_vino)
WHERE ss.id_sala = 1
ORDER BY ss.cod_vino
LIMIT 5;

DO $$
DECLARE
    v_nro_comprobante INT;
    v_cantidad_renglones INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = 1)
       OR NOT EXISTS (SELECT 1 FROM sala_venta WHERE id_sala = 1)
       OR (
           SELECT COUNT(*)
           FROM stock_sala
           WHERE id_sala = 1 AND cantidad > 0
       ) < 3 THEN
        RAISE NOTICE
            'I3 omitida: requiere cliente 1, sala 1 y al menos 3 vinos con stock';
        RETURN;
    END IF;

    INSERT INTO comprobante (id_cliente, id_sala)
    VALUES (1, 1)
    RETURNING nro_comprobante INTO v_nro_comprobante;

    INSERT INTO renglon_comprobante
        (nro_comprobante, cod_vino, cantidad, precio_unitario)
    SELECT v_nro_comprobante, v.cod_vino, 1, v.precio
    FROM stock_sala AS ss
    JOIN vino AS v USING (cod_vino)
    WHERE ss.id_sala = 1 AND ss.cantidad > 0
    ORDER BY v.cod_vino
    LIMIT 3;

    GET DIAGNOSTICS v_cantidad_renglones = ROW_COUNT;
    IF v_cantidad_renglones <> 3 THEN
        RAISE EXCEPTION 'I3 esperaba 3 renglones; insertó %',
            v_cantidad_renglones;
    END IF;

    RAISE NOTICE 'I3 comprobante %, total con descuento: %',
        v_nro_comprobante, fn_total_comprobante(v_nro_comprobante);
END;
$$;

SELECT COUNT(*) AS comprobantes_cliente_sala_despues
FROM comprobante
WHERE id_cliente = 1 AND id_sala = 1;
SELECT ss.cod_vino, v.nombre, ss.cantidad AS stock_despues
FROM stock_sala AS ss
JOIN vino AS v USING (cod_vino)
WHERE ss.id_sala = 1
ORDER BY ss.cod_vino
LIMIT 5;
ROLLBACK;

-- I4. Insertar una nueva bodega con CUIT de ejemplo; el filtro hace la
-- demostración reejecutable sin duplicar esa clave.
BEGIN;
SELECT cuit, razon_social
FROM bodega
WHERE cuit = '20999999999';

INSERT INTO bodega (cuit, razon_social, domicilio)
SELECT '20999999999', 'Bodega Etapa 5', 'Domicilio de prueba, Mendoza'
WHERE NOT EXISTS (
    SELECT 1 FROM bodega WHERE cuit = '20999999999'
)
RETURNING cuit, razon_social, domicilio;

SELECT cuit, razon_social, domicilio
FROM bodega
WHERE cuit = '20999999999';
ROLLBACK;

-- I5. Insertar una sala de ejemplo en General Alvear (CP 5603).
BEGIN;
SELECT id_sala, calle, numero, codigo_postal
FROM sala_venta
WHERE calle = 'Av. Etapa 5'
  AND numero = '100'
  AND codigo_postal = '5603';

INSERT INTO sala_venta (calle, numero, dia_cierre, codigo_postal)
SELECT 'Av. Etapa 5', '100', 'lunes', '5603'
WHERE EXISTS (
    SELECT 1 FROM localidad WHERE codigo_postal = '5603'
)
AND NOT EXISTS (
    SELECT 1
    FROM sala_venta
    WHERE calle = 'Av. Etapa 5'
      AND numero = '100'
      AND codigo_postal = '5603'
)
RETURNING id_sala, calle, numero, codigo_postal;

SELECT id_sala, calle, numero, codigo_postal
FROM sala_venta
WHERE calle = 'Av. Etapa 5'
  AND numero = '100'
  AND codigo_postal = '5603';
ROLLBACK;

-- I6. Crear un ingreso en confección por 120 botellas de un Malbec de 750 ml.
-- Se selecciona un vino y transportista existentes; cambiar el filtro del vino
-- si se desea apuntar a otro producto del dataset.
BEGIN;
SELECT i.cod_ingreso, i.estado, ri.cod_vino, ri.cantidad
FROM ingreso AS i
JOIN renglon_ingreso AS ri USING (cod_ingreso)
WHERE ri.cantidad = 120
ORDER BY i.cod_ingreso DESC
LIMIT 5;
SELECT cod_vino, nombre, volumen_ml, cuit_bodega
FROM vino
WHERE nombre ILIKE '%Malbec%' AND volumen_ml = 750
ORDER BY cod_vino
LIMIT 5;

WITH vino_seleccionado AS (
    SELECT cod_vino, cuit_bodega
    FROM vino
    WHERE nombre ILIKE '%Malbec%' AND volumen_ml = 750
    ORDER BY cod_vino
    LIMIT 1
),
transportista_seleccionado AS (
    SELECT cod_transportista
    FROM transportista
    ORDER BY cod_transportista
    LIMIT 1
),
ingreso_nuevo AS (
    INSERT INTO ingreso (cod_transportista, cuit_bodega)
    SELECT ts.cod_transportista, vs.cuit_bodega
    FROM transportista_seleccionado AS ts
    CROSS JOIN vino_seleccionado AS vs
    RETURNING cod_ingreso
),
renglon_nuevo AS (
    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    SELECT n.cod_ingreso, vs.cod_vino, 120
    FROM ingreso_nuevo AS n
    CROSS JOIN vino_seleccionado AS vs
    RETURNING cod_ingreso, cod_vino, cantidad
)
SELECT rn.cod_ingreso, i.estado, rn.cod_vino, v.nombre, rn.cantidad
FROM renglon_nuevo AS rn
JOIN ingreso AS i USING (cod_ingreso)
JOIN vino AS v USING (cod_vino);

SELECT i.cod_ingreso, i.estado, ri.cod_vino, ri.cantidad
FROM ingreso AS i
JOIN renglon_ingreso AS ri USING (cod_ingreso)
WHERE ri.cantidad = 120
ORDER BY i.cod_ingreso DESC
LIMIT 5;
ROLLBACK;
