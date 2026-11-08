# H3 - Carga masiva

## Implementación

La carga se encuentra en [seed.py](../db/seed/seed.py). Usa `Faker`, `random`
con semilla fija y `psycopg`. Los catálogos reales se encuentran en
[catalogos/](../db/seed/catalogos/).

La carga se ejecuta en una única transacción y usa inserciones por lotes. Los
triggers permanecen activos: los documentos se crean en `en_confeccion`, las
ventas descuentan stock mediante el trigger correspondiente y los cambios de
precio generan auditoría.

## Volúmenes obtenidos

La configuración por defecto produjo:

| Tabla | Filas |
| --- | ---: |
| `cliente` | 20.000 |
| `parcela` | 12.000 |
| `lote_uva` | 12.000 |
| `analisis_calidad` | 12.000 |
| `comprobante` | 20.000 |
| `renglon_comprobante` | 120.000 |

Las 28 tablas tienen al menos una fila. Se superan los mínimos de tres tablas
con más de 10.000 filas y una tabla con más de 100.000 filas.

## Medición

Con una carga reducida de 100 comprobantes y 1.000 renglones, usando la misma
semilla y configuración:

| Tamaño de lote | Tiempo |
| ---: | ---: |
| 1 (fila por fila) | 2,63 s |
| 5.000 | 0,69 s |

La comparación incluye la preparación del proceso Python y se realizó sobre la
misma base local; el resultado muestra el costo de ejecutar una sentencia por
fila frente a agrupar inserciones.

La carga completa de 20.000 comprobantes y 120.000 renglones finalizó en 64,75
segundos en el entorno local de validación.

## Controles

Los controles están en [controles.sql](../db/seed/controles.sql). Luego de la
carga completa devolvieron `OK` para:

- Tablas vacías.
- Stocks negativos.
- Composiciones que no suman 100 %.
- Ventas con stock negativo.
- Renglones huérfanos.
- Campañas duplicadas por parcela.

## Reproducibilidad y backup

La semilla por defecto es `42`. Puede cambiarse con `SEED`; los conteos pueden
reducirse mediante las variables `SEED_*` documentadas en
[db/seed/README.md](../db/seed/README.md).

El backup se genera con:

```powershell
docker exec bodegas_db pg_dump -U postgres -d bodegas_atuel `
  | gzip > .\db\seed\dump_completo.sql.gz
```
