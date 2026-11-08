-- Controles de consistencia de la etapa 3.

SELECT relname AS tabla, n_live_tup AS filas_estimadas
FROM pg_stat_user_tables
ORDER BY relname;

SELECT 'tablas_vacias' AS control, count(*) AS resultado
FROM (
    SELECT relname
    FROM pg_stat_user_tables
    WHERE n_live_tup = 0
) AS tablas;

SELECT 'stocks_negativos' AS control, count(*) AS resultado
FROM (
    SELECT cod_vino
    FROM stock_deposito
    WHERE cantidad < 0
    UNION ALL
    SELECT cod_vino
    FROM stock_sala
    WHERE cantidad < 0
) AS stocks;

SELECT 'composiciones_invalidas' AS control, count(*) AS resultado
FROM (
    SELECT cod_vino
    FROM composicion
    GROUP BY cod_vino
    HAVING sum(porcentaje) <> 100
) AS composiciones;

SELECT 'ventas_con_stock_negativo' AS control, count(*) AS resultado
FROM renglon_comprobante AS rc
JOIN comprobante AS c USING (nro_comprobante)
JOIN stock_sala AS ss
  ON ss.id_sala = c.id_sala
 AND ss.cod_vino = rc.cod_vino
WHERE ss.cantidad < 0;

SELECT 'renglones_huerfanos' AS control, count(*) AS resultado
FROM renglon_comprobante AS rc
LEFT JOIN comprobante AS c USING (nro_comprobante)
WHERE c.nro_comprobante IS NULL;

SELECT 'campanas_duplicadas' AS control, count(*) AS resultado
FROM (
    SELECT id_finca, nro_parcela, anio_campana
    FROM lote_uva
    GROUP BY id_finca, nro_parcela, anio_campana
    HAVING count(*) > 1
) AS lotes;

SELECT 'resultado' AS control,
       CASE
           WHEN NOT EXISTS (
               SELECT 1 FROM pg_stat_user_tables WHERE n_live_tup = 0
           )
           AND NOT EXISTS (
               SELECT 1 FROM stock_deposito WHERE cantidad < 0
               UNION ALL
               SELECT 1 FROM stock_sala WHERE cantidad < 0
           )
           AND NOT EXISTS (
               SELECT 1
               FROM composicion
               GROUP BY cod_vino
               HAVING sum(porcentaje) <> 100
           )
           THEN 'OK'
           ELSE 'REVISAR'
       END AS estado;
