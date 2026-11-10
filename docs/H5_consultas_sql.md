# Etapa 5: Consultas SQL

## Objetivo

Resolver en PostgreSQL las operaciones y consultas de la sección 8 del trabajo
práctico, usando el esquema y las reglas de integridad existentes. Las
operaciones que modifican filas se muestran dentro de transacciones y terminan
con `ROLLBACK` para que las demostraciones no persistan cambios.

## Consignas implementadas

### UPDATE

- **U1:** informa el total recalculado de cada comprobante con el descuento
  aplicable. Como `comprobante` no tiene una columna de total, se calcula el
  resultado con `fn_total_comprobante()` y no se actualizan renglones históricos.
  Para exportadores con más de tres permisos se aplica en el cálculo el 35% de
  U6.
- **U2:** aumenta 20% el salario de empleados con más de cinco años, usando
  `fn_antiguedad_anios()`.
- **U3:** aumenta 13% el precio de los vinos de la bodega de CUIT
  `20000000001`; muestra el registro de auditoría generado por el trigger.
- **U4:** intercambia lunes y miércoles en una sola sentencia `UPDATE`.
- **U5:** descuenta 15% a los diez vinos con menos botellas vendidas, contando
  como cero los vinos sin ventas; muestra el efecto del trigger de auditoría.
- **U6:** identifica exportadores con más de tres permisos y calcula el 35%.
  El esquema no almacena un descuento editable; de acuerdo con la decisión
  tomada para esta etapa, el resultado se informa sin modificar datos ni
  alterar `fn_descuento_cliente()`.

### INSERT

- **I1:** asigna la cobertura de General Alvear (CP `5603`) al transportista con
  menos ingresos durante los últimos tres meses; desempata por código y evita
  duplicar la relación.
- **I2:** crea el maridaje «cordero al disco» (18 °C) si hay vinos tintos de al
  menos 14° y lo asocia sin duplicar vínculos.
- **I3:** genera un comprobante para el cliente 1 en la sala 1 con tres vinos
  que tengan stock positivo. El trigger de venta descuenta el stock y
  `fn_total_comprobante()` informa el total. Los identificadores se pueden
  cambiar en el bloque.
- **I4:** inserta una bodega de ejemplo, evitando duplicar su CUIT.
- **I5:** inserta una sala de ejemplo en General Alvear si existe el CP `5603`.
- **I6:** crea un ingreso en confección por 120 unidades de un vino Malbec de
  750 ml y selecciona una bodega y un transportista existentes.

### DELETE

- **D1:** borra comprobantes de socios con más de cinco años; sus renglones se
  eliminan mediante `ON DELETE CASCADE`.
- **D2:** elimina cepas que no se usan en composiciones ni parcelas.
- **D3:** elimina empleados con menos de dos años de antigüedad de salas de
  San Rafael.
- **D4:** elimina socios con más de cinco años de antigüedad y sin compras.
- **D5:** elimina ingresos procesados con más de 365 días; sus renglones se
  eliminan por cascada.
- **D6:** elimina socios sin compras que viven en San Rafael.

### SELECT

- **S1:** top diez vinos por botellas vendidas, con ranking.
- **S2:** vinos vendidos en todas las salas, mediante división relacional con
  doble `NOT EXISTS`.
- **S3:** clientes compradores por tipo en sala 1 durante los últimos siete
  días.
- **S4:** top cinco salas por unidades solicitadas del vino 1 en transferencias
  de los últimos quince días.
- **S5:** salas empatadas con el menor número de transferencias no procesadas.
- **S6:** vinos sin stock en sala 1 que sí tienen stock en el depósito.
- **S7:** transportista con más ingresos en el último mes móvil, incluyendo
  empates.
- **S8:** monto neto de ventas por sala en los últimos tres meses móviles,
  incluyendo salas sin ventas.
- **S9:** ficha de un vino con cepas, porcentajes, bodega, maridajes y stock
  total, agregando por separado para evitar multiplicar resultados.
- **S10:** rendimiento en kg/ha por parcela y campaña y comparación con el
  promedio de su finca y campaña, usando CTE y subconsulta correlacionada.
- **S11:** ranking mensual de vinos por sala y ventas netas acumuladas por sala
  mediante funciones de ventana.
- **S12:** dos resultados: clientes que compraron todos los vinos de la bodega
  indicada (división con `NOT EXISTS`) y clientes que nunca compraron un vino
  tinto (anti-join con `NOT EXISTS`).

Los períodos móviles se calculan respecto de `CURRENT_DATE`. Los valores de
ejemplo (IDs, CUIT, CP y localidad) están comentados junto a cada consulta para
que se puedan cambiar por otros del conjunto de datos.

## Archivos utilizados

- `consultas/update.sql`
- `consultas/insert.sql`
- `consultas/delete.sql`
- `consultas/select.sql`
- Migraciones existentes `db/migrations/001_esquema.sql` a
  `db/migrations/008_indices.sql`, sin cambios.
- `db/seed/seed.py` y `db/seed/README.md`, revisados para evaluar la carga; no
  se ejecutó el seed.

## Ejecución

Desde PowerShell, con el contenedor `bodegas_db` activo:

```powershell
$utf8 = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$archivos = @("insert.sql", "update.sql", "delete.sql", "select.sql")
foreach ($archivo in $archivos) {
    Get-Content -Raw -Encoding UTF8 ".\consultas\$archivo" |
        docker exec -i bodegas_db psql -U postgres -d bodegas_atuel -v ON_ERROR_STOP=1
}
```

Los archivos de modificaciones muestran el estado previo, la operación, el
estado posterior y `ROLLBACK`. U1 y U6 son consultas de cálculo y no modifican
filas.

## Pruebas y resultados

- Se verificó la rama `Etapa5`; el árbol estaba limpio antes de los cambios.
- El contenedor PostgreSQL 15 estaba activo. En la base principal se comprobó
  que `vino`, `cliente`, `comprobante` y `sala_venta` tenían cero filas.
- No había un extractor de PDF disponible en el entorno. Se usó `Enunciado.md`,
  que contiene el objetivo, los pasos, los criterios de aceptación de Etapa 5 y
  las consignas completas de las secciones 8.1 a 8.5.
- No se ejecutó el seed: `SEED_RESET` vale `1` por defecto y el script hace
  `TRUNCATE ... RESTART IDENTITY CASCADE` sobre las tablas de datos.
- La batería existente `db/tests/db_tests.sql` finalizó con
  `OK: pruebas de etapa 2 finalizadas` en otra base temporal; se verificaron
  restricciones, transiciones de estado, auditoría de precios, stock y
  procedimientos transaccionales.
- Se creó una base temporal aislada, se aplicaron las ocho migraciones y se
  cargaron fixtures de prueba. Los cuatro archivos se ejecutaron con
  `ON_ERROR_STOP`; todos terminaron sin errores.
- En las fixtures, I3 insertó tres renglones, calculó un total de `2700.00` y
  el trigger redujo en una unidad el stock de cada vino. U3 y U5 mostraron las
  filas de auditoría que genera el trigger de precio. D1 y D5 verificaron las
  cascadas; D2–D6 encontraron y eliminaron sus filas de prueba. Todos los
  cambios de las consultas de modificación se revirtieron.
- S1–S12 devolvieron resultados con las fixtures, incluido S10 con una parcela
  por debajo del promedio. Se ejecutó `EXPLAIN (ANALYZE, BUFFERS)` sobre S9,
  S10, S11 y las dos consultas de S12; todas finalizaron correctamente.
- No se encontró un archivo de medición de rendimiento de Etapa 4 para ejecutar
  su conjunto de consultas.
- El seed no requiere dependencias adicionales para esta etapa; no se instaló
  nada.

## Problemas encontrados y resolución

1. U1 está en la sección UPDATE, pero el esquema no persiste el total del
   comprobante. Se resolvió como cálculo mediante la función existente, sin
   agregar columnas ni modificar renglones.
2. U6 pide cambiar descuentos, pero `cliente` no tiene un campo de descuento y
   la función existente fija el 30% para exportadores. Se informa el 35%
   calculado para quienes superan tres permisos, sin modificar esquema ni
   función, conforme a la decisión tomada.
3. La base principal está vacía y el seed predeterminado es destructivo. Las
   pruebas se aislaron en otra base; no se tocó la base principal ni se
   vaciaron volúmenes de Docker.

## Estado

Las consignas U1–U6, I1–I6, D1–D6 y S1–S12 están implementadas y probadas con
PostgreSQL 15 sobre fixtures. La etapa queda lista para revisión/entrega con
las dos limitaciones documentadas de U1 y U6; para probar sobre el dataset
masivo se necesita autorización antes de ejecutar el seed.
