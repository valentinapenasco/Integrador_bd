\set ON_ERROR_STOP on

-- D1. Borrar comprobantes de más de 5 años de clientes socios.
-- ON DELETE CASCADE elimina también sus renglones.
BEGIN;
SELECT COUNT(*) AS comprobantes_a_borrar
FROM comprobante AS c
JOIN cliente AS cl USING (id_cliente)
WHERE cl.tipo_cliente = 'socio'
  AND c.fecha < CURRENT_DATE - INTERVAL '5 years';
SELECT COUNT(*) AS renglones_en_comprobantes_a_borrar
FROM renglon_comprobante AS rc
JOIN comprobante AS c USING (nro_comprobante)
JOIN cliente AS cl USING (id_cliente)
WHERE cl.tipo_cliente = 'socio'
  AND c.fecha < CURRENT_DATE - INTERVAL '5 years';

DELETE FROM comprobante AS c
USING cliente AS cl
WHERE cl.id_cliente = c.id_cliente
  AND cl.tipo_cliente = 'socio'
  AND c.fecha < CURRENT_DATE - INTERVAL '5 years';

SELECT COUNT(*) AS comprobantes_viejos_restantes
FROM comprobante AS c
JOIN cliente AS cl USING (id_cliente)
WHERE cl.tipo_cliente = 'socio'
  AND c.fecha < CURRENT_DATE - INTERVAL '5 years';
ROLLBACK;

-- D2. Eliminar cepas que no estén en composicion ni plantadas en parcela.
BEGIN;
SELECT c.id_cepa, c.nombre
FROM cepa AS c
WHERE NOT EXISTS (
    SELECT 1 FROM composicion AS co WHERE co.id_cepa = c.id_cepa
)
AND NOT EXISTS (
    SELECT 1 FROM parcela AS p WHERE p.id_cepa = c.id_cepa
)
ORDER BY c.id_cepa;

DELETE FROM cepa AS c
WHERE NOT EXISTS (
    SELECT 1 FROM composicion AS co WHERE co.id_cepa = c.id_cepa
)
AND NOT EXISTS (
    SELECT 1 FROM parcela AS p WHERE p.id_cepa = c.id_cepa
)
RETURNING c.id_cepa, c.nombre;

SELECT COUNT(*) AS cepas_sin_uso_restantes
FROM cepa AS c
WHERE NOT EXISTS (
    SELECT 1 FROM composicion AS co WHERE co.id_cepa = c.id_cepa
)
AND NOT EXISTS (
    SELECT 1 FROM parcela AS p WHERE p.id_cepa = c.id_cepa
);
ROLLBACK;

-- D3. Eliminar empleados de la localidad San Rafael con menos de 2 años
-- de antigüedad. Cambiar el nombre de localidad para otra sala.
BEGIN;
SELECT e.cuit, e.nombre, e.fecha_ingreso, s.id_sala, l.nombre AS localidad
FROM empleado AS e
JOIN sala_venta AS s USING (id_sala)
JOIN localidad AS l USING (codigo_postal)
WHERE l.nombre = 'San Rafael'
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years'
ORDER BY e.cuit;

DELETE FROM empleado AS e
USING sala_venta AS s, localidad AS l
WHERE s.id_sala = e.id_sala
  AND l.codigo_postal = s.codigo_postal
  AND l.nombre = 'San Rafael'
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years'
RETURNING e.cuit, e.nombre, e.fecha_ingreso, e.id_sala;

SELECT COUNT(*) AS empleados_que_cumplen_el_filtro
FROM empleado AS e
JOIN sala_venta AS s USING (id_sala)
JOIN localidad AS l USING (codigo_postal)
WHERE l.nombre = 'San Rafael'
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years';
ROLLBACK;

-- D4. Borrar socios sin compras dados de alta hace más de 5 años.
BEGIN;
SELECT cl.id_cliente, cl.razon_social, cl.fecha_alta
FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  )
ORDER BY cl.id_cliente;

DELETE FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  )
RETURNING cl.id_cliente, cl.razon_social, cl.fecha_alta;

SELECT COUNT(*) AS socios_sin_compras_antiguos_restantes
FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  );
ROLLBACK;

-- D5. Eliminar ingresos procesados con fecha anterior a los últimos 365 días.
-- Sus renglones se eliminan por ON DELETE CASCADE.
BEGIN;
SELECT i.cod_ingreso, i.fecha, i.estado
FROM ingreso AS i
WHERE i.estado = 'procesado'
  AND i.fecha < CURRENT_DATE - INTERVAL '365 days'
ORDER BY i.cod_ingreso;

DELETE FROM ingreso AS i
WHERE i.estado = 'procesado'
  AND i.fecha < CURRENT_DATE - INTERVAL '365 days'
RETURNING i.cod_ingreso, i.fecha, i.estado;

SELECT COUNT(*) AS ingresos_procesados_antiguos_restantes
FROM ingreso
WHERE estado = 'procesado'
  AND fecha < CURRENT_DATE - INTERVAL '365 days';
ROLLBACK;

-- D6. Borrar socios sin compras que viven en San Rafael.
-- cliente.localidad es texto libre; el valor se puede reemplazar por otra
-- localidad existente en el dataset.
BEGIN;
SELECT cl.id_cliente, cl.razon_social, cl.localidad
FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.localidad = 'San Rafael'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  )
ORDER BY cl.id_cliente;

DELETE FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.localidad = 'San Rafael'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  )
RETURNING cl.id_cliente, cl.razon_social, cl.localidad;

SELECT COUNT(*) AS socios_sin_compras_de_san_rafael_restantes
FROM cliente AS cl
WHERE cl.tipo_cliente = 'socio'
  AND cl.localidad = 'San Rafael'
  AND NOT EXISTS (
      SELECT 1
      FROM comprobante AS c
      WHERE c.id_cliente = cl.id_cliente
  );
ROLLBACK;
