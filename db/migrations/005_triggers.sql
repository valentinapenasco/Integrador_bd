-- RN-09: evita vender más unidades de las disponibles en una sala.
CREATE OR REPLACE FUNCTION tg_validar_stock_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    SELECT cantidad
      INTO v_stock
      FROM stock_sala
     WHERE id_sala = (
         SELECT id_sala
           FROM comprobante
          WHERE nro_comprobante = NEW.nro_comprobante
     )
       AND cod_vino = NEW.cod_vino
     FOR UPDATE;

    IF NOT FOUND OR v_stock < NEW.cantidad THEN
        RAISE EXCEPTION
            'Stock insuficiente para vino %: disponible %, solicitado %',
            NEW.cod_vino, COALESCE(v_stock, 0), NEW.cantidad
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_validar_stock_venta
BEFORE INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION tg_validar_stock_venta();

-- RN-08 y RN-09: descuenta el stock una vez insertado el renglón.
CREATE OR REPLACE FUNCTION tg_descontar_stock_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_sala INT;
BEGIN
    SELECT id_sala
      INTO v_id_sala
      FROM comprobante
     WHERE nro_comprobante = NEW.nro_comprobante;

    UPDATE stock_sala
       SET cantidad = cantidad - NEW.cantidad
     WHERE id_sala = v_id_sala
       AND cod_vino = NEW.cod_vino;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_descontar_stock_venta
AFTER INSERT ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION tg_descontar_stock_venta();

-- RN-10 y RN-11: solo se permiten transiciones progresivas de estado.
CREATE OR REPLACE FUNCTION tg_validar_transicion_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'Un documento nuevo debe comenzar en confección'
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.estado <> OLD.estado THEN
        IF NOT (
            (OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado')
            OR (OLD.estado = 'terminado' AND NEW.estado = 'procesado')
        ) THEN
            RAISE EXCEPTION 'Transición de estado inválida: % -> %',
                OLD.estado, NEW.estado
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_validar_estado_ingreso
BEFORE INSERT OR UPDATE OF estado ON ingreso
FOR EACH ROW
EXECUTE FUNCTION tg_validar_transicion_estado();

CREATE TRIGGER tr_validar_estado_transferencia
BEFORE INSERT OR UPDATE OF estado ON transferencia
FOR EACH ROW
EXECUTE FUNCTION tg_validar_transicion_estado();

-- RN-12: los renglones solo se modifican mientras la cabecera está en
-- confección.
CREATE OR REPLACE FUNCTION tg_bloquear_renglon_documento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_id_documento INT;
BEGIN
    IF TG_TABLE_NAME = 'renglon_ingreso' THEN
        IF TG_OP = 'DELETE' THEN
            v_id_documento := OLD.cod_ingreso;
        ELSE
            v_id_documento := NEW.cod_ingreso;
        END IF;
    ELSE
        IF TG_OP = 'DELETE' THEN
            v_id_documento := OLD.nro_transferencia;
        ELSE
            v_id_documento := NEW.nro_transferencia;
        END IF;
    END IF;

    IF TG_TABLE_NAME = 'renglon_ingreso' THEN
        SELECT estado INTO v_estado
          FROM ingreso
         WHERE cod_ingreso = v_id_documento;
    ELSE
        SELECT estado INTO v_estado
          FROM transferencia
         WHERE nro_transferencia = v_id_documento;
    END IF;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'No se puede modificar un documento que no está en confección'
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_bloquear_renglones_ingreso
BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
FOR EACH ROW
EXECUTE FUNCTION tg_bloquear_renglon_documento();

CREATE TRIGGER tr_bloquear_renglones_transferencia
BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
FOR EACH ROW
EXECUTE FUNCTION tg_bloquear_renglon_documento();

-- RN-11: la fecha de confección siempre corresponde al día de creación.
CREATE OR REPLACE FUNCTION tg_controlar_fecha_transferencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
    ELSIF NEW.fecha_confeccion <> OLD.fecha_confeccion THEN
        RAISE EXCEPTION 'La fecha de confección no puede modificarse'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_controlar_fecha_transferencia
BEFORE INSERT OR UPDATE OF fecha_confeccion ON transferencia
FOR EACH ROW
EXECUTE FUNCTION tg_controlar_fecha_transferencia();

-- RN-13: registra cada modificación del precio de un vino.
CREATE OR REPLACE FUNCTION tg_auditar_precio_vino()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.precio IS DISTINCT FROM OLD.precio THEN
        INSERT INTO auditoria_precio (
            cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario
        )
        VALUES (
            OLD.cod_vino, OLD.precio, NEW.precio, CURRENT_TIMESTAMP, current_user
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER tr_auditar_precio_vino
AFTER UPDATE OF precio ON vino
FOR EACH ROW
EXECUTE FUNCTION tg_auditar_precio_vino();

-- RN-05: al cerrar la transacción, cada vino debe tener composición que sume
-- exactamente 100%.
CREATE OR REPLACE FUNCTION tg_validar_composicion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_vino INT;
    v_total NUMERIC(7,2);
BEGIN
    IF TG_OP <> 'DELETE' THEN
        v_cod_vino := NEW.cod_vino;
    ELSE
        v_cod_vino := OLD.cod_vino;
    END IF;

    IF EXISTS (SELECT 1 FROM vino WHERE cod_vino = v_cod_vino) THEN
        SELECT COALESCE(SUM(porcentaje), 0)
          INTO v_total
          FROM composicion
         WHERE cod_vino = v_cod_vino;

        IF v_total <> 100 THEN
            RAISE EXCEPTION
                'La composición del vino % debe sumar 100%%; suma actual: %',
                v_cod_vino, v_total
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER tr_validar_composicion
AFTER INSERT OR UPDATE OR DELETE ON composicion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION tg_validar_composicion();
