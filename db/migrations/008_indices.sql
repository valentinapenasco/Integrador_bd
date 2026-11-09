-- HITO 4: ÍNDICES Y RENDIMIENTO
-- Estos índices se justifican y se miden en db/performance/medir_etapa4.sql.

-- Clave foránea usada al agrupar y filtrar ventas por cliente.
CREATE INDEX IF NOT EXISTS idx_comprobante_cliente
    ON comprobante (id_cliente);

-- Clave foránea usada al consultar el detalle de un vino.
CREATE INDEX IF NOT EXISTS idx_renglon_comprobante_vino
    ON renglon_comprobante (cod_vino);

-- Índice compuesto para reportes por período y sala.
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_sala
    ON comprobante (fecha, id_sala);

-- Índice parcial para localizar únicamente transferencias aún no procesadas.
CREATE INDEX IF NOT EXISTS idx_transferencia_pendiente
    ON transferencia (id_sala_solicitante, fecha_confeccion)
    WHERE estado <> 'procesado';

-- Variante BRIN adecuada para fechas insertadas aproximadamente en orden.
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_brin
    ON comprobante USING BRIN (fecha)
    WITH (pages_per_range = 32);

-- Índice de expresión para búsquedas sin distinguir mayúsculas.
CREATE INDEX IF NOT EXISTS idx_bodega_razon_social_lower
    ON bodega (lower(razon_social));
