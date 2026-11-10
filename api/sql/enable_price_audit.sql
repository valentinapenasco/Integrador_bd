CREATE OR REPLACE FUNCTION public.tg_auditar_precio_vino()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF NEW.precio IS DISTINCT FROM OLD.precio THEN
        INSERT INTO public.auditoria_precio (
            cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario
        )
        VALUES (
            OLD.cod_vino, OLD.precio, NEW.precio, CURRENT_TIMESTAMP, session_user
        );
    END IF;

    RETURN NEW;
END;
$$;
