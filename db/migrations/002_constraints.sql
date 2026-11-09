-- Integridad de dominio y unicidad adicional del esquema de Bodegas del Atuel.

ALTER TABLE vino
    ADD CONSTRAINT uq_vino_nombre_anada_volumen
        UNIQUE (nombre, anada, volumen_ml),
    ADD CONSTRAINT ck_vino_precio_positivo CHECK (precio > 0),
    ADD CONSTRAINT ck_vino_volumen_positivo CHECK (volumen_ml > 0),
    ADD CONSTRAINT ck_vino_graduacion_valida CHECK (graduacion BETWEEN 5 AND 20);

ALTER TABLE lote_uva
    ADD CONSTRAINT uq_lote_parcela_campana
        UNIQUE (id_finca, nro_parcela, anio_campana),
    ADD CONSTRAINT ck_lote_kilos_positivos CHECK (kilos > 0);

ALTER TABLE transportista
    ADD CONSTRAINT uq_transportista_cuit UNIQUE (cuit);

ALTER TABLE cliente
    ADD CONSTRAINT uq_cliente_documento UNIQUE (tipo_doc, nro_doc);

ALTER TABLE finca
    ADD CONSTRAINT ck_finca_superficie_positiva CHECK (superficie_ha > 0);

ALTER TABLE parcela
    ADD CONSTRAINT ck_parcela_superficie_positiva CHECK (superficie > 0),
    ADD CONSTRAINT ck_parcela_anio_valido CHECK (anio_plantacion > 0);

ALTER TABLE composicion
    ADD CONSTRAINT ck_composicion_porcentaje_valido
        CHECK (porcentaje > 0 AND porcentaje <= 100);

ALTER TABLE maridaje
    ADD CONSTRAINT ck_maridaje_temperatura_valida
        CHECK (temp_servicio BETWEEN 0 AND 40);

ALTER TABLE stock_deposito
    ADD CONSTRAINT ck_stock_deposito_no_negativo CHECK (cantidad >= 0);

ALTER TABLE stock_sala
    ADD CONSTRAINT ck_stock_sala_no_negativo CHECK (cantidad >= 0);

ALTER TABLE renglon_ingreso
    ADD CONSTRAINT ck_renglon_ingreso_cantidad_positiva CHECK (cantidad > 0);

ALTER TABLE renglon_transferencia
    ADD CONSTRAINT ck_renglon_transferencia_cantidad_positiva CHECK (cantidad > 0);

ALTER TABLE renglon_comprobante
    ADD CONSTRAINT ck_renglon_comprobante_cantidad_positiva CHECK (cantidad > 0),
    ADD CONSTRAINT ck_renglon_comprobante_precio_positivo CHECK (precio_unitario > 0);

ALTER TABLE analisis_calidad
    ADD CONSTRAINT ck_analisis_brix_no_negativo CHECK (brix >= 0),
    ADD CONSTRAINT ck_analisis_ph_valido CHECK (ph BETWEEN 0 AND 14),
    ADD CONSTRAINT ck_analisis_acidez_no_negativa CHECK (acidez >= 0);

ALTER TABLE permiso_exportacion
    ADD CONSTRAINT ck_permiso_vigencia_valida
        CHECK (fecha_vencimiento > fecha_emision);
