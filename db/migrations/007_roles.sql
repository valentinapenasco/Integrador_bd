DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodegas_owner') THEN
        CREATE ROLE bodegas_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodegas_api') THEN
        CREATE ROLE bodegas_api LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodegas_reportes') THEN
        CREATE ROLE bodegas_reportes LOGIN;
    END IF;
END;
$$;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO bodegas_owner, bodegas_api, bodegas_reportes;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bodegas_owner;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bodegas_owner;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO bodegas_owner;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO bodegas_owner;

GRANT SELECT, INSERT, UPDATE, DELETE
ON finca, cepa, parcela, bodega, lote_uva, analisis_calidad,
   vino, composicion, maridaje, vino_maridaje, localidad, sala_venta,
   empleado, stock_deposito, stock_sala, transportista,
   transportista_localidad, ingreso, renglon_ingreso, transferencia,
   renglon_transferencia, cliente, distribuidor, exportador,
   permiso_exportacion, comprobante, renglon_comprobante
TO bodegas_api;

GRANT SELECT ON auditoria_precio TO bodegas_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO bodegas_api;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO bodegas_api;
GRANT EXECUTE ON PROCEDURE sp_procesar_ingreso(INT) TO bodegas_api;
GRANT EXECUTE ON PROCEDURE sp_procesar_transferencia(INT) TO bodegas_api;

GRANT SELECT ON vw_stock_total_vino, vw_ventas_mensuales_sala,
    vw_documentos_pendientes TO bodegas_reportes;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON FUNCTIONS FROM PUBLIC;
