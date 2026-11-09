# H4 - Índices y rendimiento

## Alcance

La implementación está en
[`db/migrations/008_indices.sql`](../db/migrations/008_indices.sql).
Incluye:

| Índice | Tipo | Objetivo |
|---|---|---|
| `idx_comprobante_cliente` | Clave foránea | Acelerar joins y agrupaciones por cliente |
| `idx_renglon_comprobante_vino` | Clave foránea | Acelerar la ficha y ventas de un vino |
| `idx_comprobante_fecha_sala` | Compuesto | Reportes por fecha y sala |
| `idx_transferencia_pendiente` | Parcial (`WHERE`) | Buscar transferencias no procesadas |
| `idx_comprobante_fecha_brin` | BRIN | Rangos sobre fechas en tablas grandes |
| `idx_bodega_razon_social_lower` | Expresión | Búsquedas sin distinguir mayúsculas |

El índice compuesto prioriza `fecha` porque los reportes filtran primero por
período y luego agrupan por sala. El índice BRIN ocupa poco espacio y es
apropiado cuando la fecha mantiene correlación con el orden físico de carga.
El índice parcial evita indexar transferencias ya procesadas.

## Instalación y ejecución completa

Requisitos:

- Docker Desktop iniciado.
- Python 3.11 o superior.
- `psycopg[binary]` y `Faker`.
- `psql` no es necesario en Windows: se puede ejecutar desde el contenedor.

Instalar las dependencias de la carga:

```powershell
py -m pip install "psycopg[binary]" Faker
```

Inicializar PostgreSQL desde cero. El borrado del volumen es necesario cuando
se modifican las migraciones, porque PostgreSQL solo ejecuta los scripts de
`docker-entrypoint-initdb.d` al crear una base nueva:

```powershell
docker compose down -v
docker compose up -d
docker compose ps
```

Cargar un dataset completo de la etapa 3:

```powershell
$env:POSTGRES_HOST = "localhost"
$env:POSTGRES_PORT = "5432"
$env:POSTGRES_DB = "bodegas_atuel"
$env:POSTGRES_USER = "postgres"
$env:POSTGRES_PASSWORD = "postgres"
py .\db\seed\seed.py
```

La carga por defecto supera los mínimos de la etapa 3 y deja una base
suficientemente grande para que los planes de ejecución sean observables.

## Cómo medir

Con la base cargada:

```powershell
Get-Content .\db\performance\medir_etapa4.sql |
  docker exec -i bodegas_db psql -U postgres -d bodegas_atuel |
  Tee-Object .\db\performance\resultado_etapa4.txt
```

El script ejecuta tres consultas selectivas y consultas de control antes y
después de crear los índices, registra
`EXPLAIN (ANALYZE, BUFFERS)`, mide una escritura con y sin los índices y muestra
un caso de baja selectividad donde PostgreSQL puede elegir `Seq Scan`.

Completar con los valores obtenidos:

| Consulta | Tiempo antes | Tiempo después | Plan antes | Plan después |
|---|---:|---:|---|---|
| Q1 - comprobantes de un cliente | 1,193 ms | 0,042 ms | Seq Scan | Index Scan |
| Q2 - renglones de un vino | 7,210 ms | 3,498 ms | Seq Scan | Index Scan |
| Q3 - comprobantes por fecha y sala | 1,144 ms | 0,275 ms | Seq Scan | Bitmap Heap/Index Scan |

Medición realizada el 09/11/2026 sobre el dataset reproducible de la etapa 3:
20.000 comprobantes y 120.000 renglones de comprobante. Los buffers y planes
completos se encuentran en
[`db/performance/resultado_etapa4.txt`](../db/performance/resultado_etapa4.txt).

La escritura de 1.000 filas en la tabla temporal tardó 1,983 ms con dos
índices activos y 1,084 ms sin ellos. Esto evidencia el costo de mantenimiento
de índices durante las escrituras.

El caso de baja selectividad tardó 4,887 ms y utilizó `Seq Scan`, porque la
condición recupera las 20.000 filas de `comprobante`; en ese escenario un
recorrido secuencial es más conveniente que recorrer un índice.

La entrega debe incluir el archivo
`db/performance/resultado_etapa4.txt` generado por el comando anterior y
reemplazar los valores `completar` por los resultados observados.

## Índice evaluado y descartado

Se evaluó un índice simple sobre `comprobante(fecha)`. Se descartó como índice
principal del reporte porque la consulta necesita además `id_sala`; el índice
compuesto `(fecha, id_sala)` representa mejor ese acceso.

No se debe afirmar que un índice mejora una consulta sin comparar `Execution
Time`, buffers y tipo de recorrido. En consultas de baja selectividad,
PostgreSQL puede preferir un `Seq Scan`; eso se documenta como parte de la
etapa.