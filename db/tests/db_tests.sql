-- Pruebas de etapa 2. Ejecutar como propietario de la base luego de las
-- migraciones 001_esquema.sql a 007_roles.sql sobre una base de pruebas vacía.
\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION pg_temp.assert_true(p_condicion BOOLEAN, p_mensaje TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF NOT COALESCE(p_condicion, FALSE) THEN
        RAISE EXCEPTION 'FALLO: %', p_mensaje;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.assert_error(p_sql TEXT, p_mensaje TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        RETURN;
    END;
    RAISE EXCEPTION 'FALLO: se esperaba un error: %', p_mensaje;
END;
$$;

INSERT INTO cepa (nombre, tipo) VALUES ('Malbec Test', 'tinta');
INSERT INTO cepa (nombre, tipo) VALUES ('Chardonnay Test', 'blanca');
INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('20111111111', 'Bodega Test', 'Domicilio 1');
INSERT INTO finca (nombre, superficie_ha, departamento, provincia)
VALUES ('Finca Test', 100, 'San Rafael', 'Mendoza');
INSERT INTO parcela (id_finca, nro_parcela, superficie, anio_plantacion, id_cepa)
VALUES (1, 1, 20, 2018, 1);
INSERT INTO vino (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
VALUES ('Vino Test', 'tinto', 2024, 750, 13, 100, '20111111111');
BEGIN;
INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (1, 1, 100);
COMMIT;
INSERT INTO localidad (codigo_postal, nombre, provincia, encargado_regional)
VALUES ('5600', 'San Rafael', 'Mendoza', 'Encargado Test');
INSERT INTO sala_venta (calle, numero, dia_cierre, codigo_postal)
VALUES ('Calle Test', '100', 'domingo', '5600');
INSERT INTO transportista
    (razon_social, cuit, email, telefono, domicilio)
VALUES
    ('Transporte Test', '20222222222', 'test@example.com', '2600000000', 'Domicilio 2');
INSERT INTO cliente
    (razon_social, tipo_doc, nro_doc, direccion, localidad, tipo_cliente)
VALUES
    ('Cliente Test', 'DNI', '12345678', 'Domicilio 3', 'San Rafael', 'socio');
INSERT INTO stock_sala (id_sala, cod_vino, cantidad) VALUES (1, 1, 10);
INSERT INTO stock_deposito (cod_vino, cantidad) VALUES (1, 20);
INSERT INTO ingreso (cod_transportista, cuit_bodega) VALUES (1, '20111111111');
INSERT INTO transferencia (id_sala_solicitante) VALUES (1);

-- RN-01 y RN-15.
SELECT pg_temp.assert_error(
    $$INSERT INTO vino
      (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
      VALUES ('Precio inválido', 'tinto', 2024, 750, 13, 0, '20111111111')$$,
    'RN-01 precio positivo'
);
SELECT pg_temp.assert_error(
    $$INSERT INTO vino
      (nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
      VALUES ('Graduación inválida', 'tinto', 2025, 750, 25, 100, '20111111111')$$,
    'RN-15 graduación'
);

-- RN-02 y RN-03.
SELECT pg_temp.assert_error(
    $$INSERT INTO sala_venta (calle, numero, dia_cierre, codigo_postal)
      VALUES ('Calle inválida', '1', 'domingo', '9999')$$,
    'RN-02 localidad inexistente'
);
SELECT pg_temp.assert_error(
    $$INSERT INTO empleado
      (cuit, nombre, fecha_ingreso, salario, id_sala)
      VALUES ('20333333333', 'Empleado Test', CURRENT_DATE, 100, 9999)$$,
    'RN-03 sala inexistente'
);

-- RN-04.
INSERT INTO lote_uva
    (anio_campana, fecha_cosecha, kilos, id_finca, nro_parcela, cuit_bodega)
VALUES (2025, '2025-03-01', 1000, 1, 1, '20111111111');
SELECT pg_temp.assert_error(
    $$INSERT INTO lote_uva
      (anio_campana, fecha_cosecha, kilos, id_finca, nro_parcela, cuit_bodega)
      VALUES (2025, '2025-03-02', 900, 1, 1, '20111111111')$$,
    'RN-04 cosecha duplicada'
);

-- RN-05.
BEGIN;
INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (1, 2, 50);
SELECT pg_temp.assert_error(
    'SET CONSTRAINTS tr_validar_composicion IMMEDIATE',
    'RN-05 composición no suma 100'
);
ROLLBACK;

-- RN-06.
SELECT pg_temp.assert_true(
    fn_descuento_cliente(1) = 0.10,
    'RN-06 descuento de socio'
);

-- RN-07.
INSERT INTO exportador (id_cliente, pais_destino) VALUES (1, 'Chile');
SELECT pg_temp.assert_error(
    $$INSERT INTO permiso_exportacion
      (fecha_emision, fecha_vencimiento, id_cliente_exportador)
      VALUES ('2026-01-02', '2026-01-01', 1)$$,
    'RN-07 vigencia de permiso'
);

-- RN-08.
INSERT INTO comprobante (id_cliente, id_sala) VALUES (1, 1);
INSERT INTO renglon_comprobante
    (nro_comprobante, cod_vino, cantidad, precio_unitario)
VALUES (1, 1, 2, 100);
SELECT pg_temp.assert_true(
    fn_total_comprobante(1) = 180.00,
    'RN-08 total con descuento'
);

-- RN-09.
SELECT pg_temp.assert_error(
    $$INSERT INTO renglon_comprobante
      (nro_comprobante, cod_vino, cantidad, precio_unitario)
      VALUES (1, 1, 100, 100)$$,
    'RN-09 stock insuficiente'
);

-- RN-10 y RN-11.
UPDATE ingreso SET estado = 'terminado' WHERE cod_ingreso = 1;
SELECT pg_temp.assert_error(
    $$UPDATE ingreso SET estado = 'en_confeccion' WHERE cod_ingreso = 1$$,
    'RN-10 transición hacia atrás'
);
SELECT pg_temp.assert_true(
    (SELECT fecha_confeccion = CURRENT_DATE FROM transferencia WHERE nro_transferencia = 1),
    'RN-11 fecha actual de transferencia'
);
SELECT pg_temp.assert_error(
    $$UPDATE transferencia
         SET fecha_confeccion = fecha_confeccion - 1
       WHERE nro_transferencia = 1$$,
    'RN-11 fecha inmutable'
);

-- RN-12.
UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = 1;
SELECT pg_temp.assert_error(
    $$INSERT INTO renglon_transferencia
      (nro_transferencia, cod_vino, cantidad) VALUES (1, 1, 1)$$,
    'RN-12 renglón de documento terminado'
);

-- RN-13.
UPDATE vino SET precio = 110 WHERE cod_vino = 1;
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM auditoria_precio WHERE cod_vino = 1) = 1,
    'RN-13 auditoría de precio'
);

-- RN-14.
SELECT pg_temp.assert_error(
    $$DELETE FROM vino WHERE cod_vino = 1$$,
    'RN-14 vino con movimientos'
);
SELECT pg_temp.assert_error(
    $$DELETE FROM bodega WHERE cuit = '20111111111'$$,
    'RN-14 bodega con movimientos'
);
SELECT pg_temp.assert_error(
    $$DELETE FROM transportista WHERE cod_transportista = 1$$,
    'RN-14 transportista con movimientos'
);

-- Operación transaccional: no debe dejar cambios parciales.
INSERT INTO transferencia (id_sala_solicitante) VALUES (1);
INSERT INTO renglon_transferencia
    (nro_transferencia, cod_vino, cantidad)
VALUES (2, 1, 100);
UPDATE transferencia SET estado = 'terminado' WHERE nro_transferencia = 2;
SELECT pg_temp.assert_error(
    $$CALL sp_procesar_transferencia(2)$$,
    'transferencia sin stock suficiente'
);
SELECT pg_temp.assert_true(
    (SELECT cantidad FROM stock_deposito WHERE cod_vino = 1) = 20,
    'rollback del procedimiento'
);

SELECT 'OK: pruebas de etapa 2 finalizadas' AS resultado;
