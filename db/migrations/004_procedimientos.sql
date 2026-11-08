-- Procesa un ingreso terminado y actualiza el stock del depósito en una
-- única operación transaccional.
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(p_cod_ingreso INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_renglon RECORD;
    v_tiene_renglones BOOLEAN := FALSE;
BEGIN
    SELECT estado
      INTO STRICT v_estado
      FROM ingreso
     WHERE cod_ingreso = p_cod_ingreso
     FOR UPDATE;

    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'El ingreso % debe estar terminado; estado actual: %',
            p_cod_ingreso, v_estado;
    END IF;

    FOR v_renglon IN
        SELECT cod_vino, cantidad
          FROM renglon_ingreso
         WHERE cod_ingreso = p_cod_ingreso
    LOOP
        v_tiene_renglones := TRUE;
        INSERT INTO stock_deposito (cod_vino, cantidad)
        VALUES (v_renglon.cod_vino, v_renglon.cantidad)
        ON CONFLICT (cod_vino)
        DO UPDATE SET cantidad = stock_deposito.cantidad + EXCLUDED.cantidad;
    END LOOP;

    IF NOT v_tiene_renglones THEN
        RAISE EXCEPTION 'El ingreso % no tiene renglones', p_cod_ingreso
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE ingreso
       SET estado = 'procesado'
     WHERE cod_ingreso = p_cod_ingreso;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'No existe el ingreso %', p_cod_ingreso
            USING ERRCODE = 'foreign_key_violation';
END;
$$;

-- Procesa una transferencia terminada verificando y descontando todo el
-- stock del depósito antes de acreditarlo en la sala solicitante.
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(p_nro_transferencia INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_id_sala INT;
    v_renglon RECORD;
    v_stock INT;
    v_tiene_renglones BOOLEAN := FALSE;
BEGIN
    SELECT estado, id_sala_solicitante
      INTO STRICT v_estado, v_id_sala
      FROM transferencia
     WHERE nro_transferencia = p_nro_transferencia
     FOR UPDATE;

    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'La transferencia % debe estar terminada; estado actual: %',
            p_nro_transferencia, v_estado;
    END IF;

    FOR v_renglon IN
        SELECT cod_vino, cantidad
          FROM renglon_transferencia
         WHERE nro_transferencia = p_nro_transferencia
    LOOP
        v_tiene_renglones := TRUE;
        SELECT cantidad
          INTO v_stock
          FROM stock_deposito
         WHERE cod_vino = v_renglon.cod_vino
         FOR UPDATE;

        IF NOT FOUND OR v_stock < v_renglon.cantidad THEN
            RAISE EXCEPTION
                'Stock insuficiente para vino %: disponible %, solicitado %',
                v_renglon.cod_vino, COALESCE(v_stock, 0), v_renglon.cantidad
                USING ERRCODE = 'check_violation';
        END IF;

        UPDATE stock_deposito
           SET cantidad = cantidad - v_renglon.cantidad
         WHERE cod_vino = v_renglon.cod_vino;

        INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
        VALUES (v_id_sala, v_renglon.cod_vino, v_renglon.cantidad)
        ON CONFLICT (id_sala, cod_vino)
        DO UPDATE SET cantidad = stock_sala.cantidad + EXCLUDED.cantidad;
    END LOOP;

    IF NOT v_tiene_renglones THEN
        RAISE EXCEPTION 'La transferencia % no tiene renglones',
            p_nro_transferencia
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE transferencia
       SET estado = 'procesado'
     WHERE nro_transferencia = p_nro_transferencia;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'No existe la transferencia %', p_nro_transferencia
            USING ERRCODE = 'foreign_key_violation';
END;
$$;
