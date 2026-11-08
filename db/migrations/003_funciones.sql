-- Devuelve el descuento aplicable al cliente según su subtipo.
CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_id_cliente INT)
RETURNS NUMERIC(5,4)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_tipo tipo_cliente_enum;
BEGIN
    SELECT tipo_cliente
      INTO STRICT v_tipo
      FROM cliente
     WHERE id_cliente = p_id_cliente;

    RETURN CASE v_tipo
        WHEN 'socio' THEN 0.10
        WHEN 'distribuidor' THEN 0.20
        WHEN 'exportador' THEN 0.30
    END;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'No existe el cliente %', p_id_cliente
            USING ERRCODE = 'foreign_key_violation';
END;
$$;

COMMENT ON FUNCTION fn_descuento_cliente(INT) IS
    'Parámetro: id_cliente. Descuento por subtipo; STABLE.';

-- Devuelve el stock disponible de un vino en una sala.
CREATE OR REPLACE FUNCTION fn_stock_sala(p_id_sala INT, p_cod_vino INT)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE((
        SELECT cantidad
          FROM stock_sala
         WHERE id_sala = p_id_sala
           AND cod_vino = p_cod_vino
    ), 0);
$$;

COMMENT ON FUNCTION fn_stock_sala(INT, INT) IS
    'Parámetros: id_sala, cod_vino. Stock actual; STABLE.';

-- Calcula el total de un comprobante aplicando el descuento del cliente.
CREATE OR REPLACE FUNCTION fn_total_comprobante(p_nro_comprobante INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id_cliente INT;
    v_subtotal NUMERIC(12,2);
BEGIN
    SELECT id_cliente
      INTO STRICT v_id_cliente
      FROM comprobante
     WHERE nro_comprobante = p_nro_comprobante;

    SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
      INTO v_subtotal
      FROM renglon_comprobante
     WHERE nro_comprobante = p_nro_comprobante;

    RETURN ROUND(v_subtotal * (1 - fn_descuento_cliente(v_id_cliente)), 2);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'No existe el comprobante %', p_nro_comprobante
            USING ERRCODE = 'foreign_key_violation';
END;
$$;

COMMENT ON FUNCTION fn_total_comprobante(INT) IS
    'Parámetro: nro_comprobante. Total con descuento; STABLE.';

-- Calcula la antigüedad laboral completa en años.
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(p_fecha_ingreso DATE)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
    SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_fecha_ingreso))::INT;
$$;

COMMENT ON FUNCTION fn_antiguedad_anios(DATE) IS
    'Parámetro: fecha_ingreso. Años completos a la fecha actual; STABLE.';
