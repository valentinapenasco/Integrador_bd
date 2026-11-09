# Carga masiva de etapa 3

## Requisitos

- Python 3.11 o superior.
- PostgreSQL con las migraciones `001_esquema.sql` a `007_roles.sql`
  aplicadas.
- Paquetes `psycopg[binary]` y `Faker`.

Instalación:

```powershell
py -m pip install "psycopg[binary]" Faker
```

## Ejecución

Configurar la conexión mediante variables de entorno. Si `DATABASE_URL` no
está definida, se usan `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`,
`POSTGRES_USER` y `POSTGRES_PASSWORD`.

```powershell
$env:POSTGRES_HOST = "localhost"
$env:POSTGRES_USER = "postgres"
$env:POSTGRES_PASSWORD = "postgres"
python .\db\seed\seed.py
```

El script usa la semilla `42`, vacía las tablas y carga un conjunto que supera
los mínimos del enunciado: más de 10.000 clientes, lotes y comprobantes, y
120.000 renglones de comprobante.

Para una prueba rápida:

```powershell
$env:SEED_CLIENTES = "100"
$env:SEED_PARCELAS = "120"
$env:SEED_LOTES = "100"
$env:SEED_COMPROBANTES = "20"
$env:SEED_RENGLONES_COMPROBANTE = "100"
$env:SEED_INGRESOS = "10"
$env:SEED_TRANSFERENCIAS = "10"
$env:SEED_VINOS = "10"
$env:SEED_SALAS = "5"
python .\db\seed\seed.py
```

`SEED_RESET=0` evita el `TRUNCATE`, pero solo debe usarse cuando el conjunto de
datos sea compatible con las restricciones de unicidad.

## Controles posteriores

Consultar conteos:

```sql
SELECT 'cliente' AS tabla, count(*) FROM cliente
UNION ALL SELECT 'lote_uva', count(*) FROM lote_uva
UNION ALL SELECT 'comprobante', count(*) FROM comprobante
UNION ALL SELECT 'renglon_comprobante', count(*) FROM renglon_comprobante;
```

Verificar stocks y composiciones:

```sql
SELECT count(*) FROM stock_deposito WHERE cantidad < 0;
SELECT count(*) FROM stock_sala WHERE cantidad < 0;
SELECT cod_vino, sum(porcentaje)
FROM composicion
GROUP BY cod_vino
HAVING sum(porcentaje) <> 100;
```

La carga mantiene los triggers activos. Los documentos se generan en
`en_confeccion`, por lo que no modifican stocks mediante los procedimientos de
procesamiento. Las ventas se insertan con stock suficiente y el trigger de
venta descuenta el stock de sala.

## Reproducibilidad y medición

`SEED` controla `random` y Faker. Dos cargas con la misma configuración y
semilla producen los mismos valores lógicos y conteos. El script informa el
tiempo total de carga. Para comparar inserción por fila con lotes, utilizar el
mismo generador con `SEED_BATCH_SIZE=1` y luego con `SEED_BATCH_SIZE=5000`,
registrando los tiempos en el informe de etapa 3.

## Backup

```powershell
docker exec bodegas_db pg_dump -U postgres -d bodegas_atuel `
  | gzip > .\db\seed\dump_completo.sql.gz
```
