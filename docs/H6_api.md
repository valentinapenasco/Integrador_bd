# Etapa 6: API REST local

La API usa FastAPI y el driver nativo psycopg, sin ORM. SQL parametrizado queda
en `api/app/dao.py`; PostgreSQL conserva las reglas, el cálculo de totales y el
manejo del stock. FastAPI publica la documentación OpenAPI en `/docs`.

## Configuración de credenciales

La aplicación se conecta como `bodegas_api`, no como propietario. Copie
`.env.example` a `.env` y configure `DB_PASSWORD` con la contraseña que ya
tenga ese rol. La migración `007_roles.sql` crea el rol, pero no le asigna
contraseña. Esta implementación no cambia credenciales de PostgreSQL: si el
rol no tiene una, la API no podrá conectar hasta que se autorice y realice por
separado el aprovisionamiento de esa credencial.

El trigger de auditoría inserta en `auditoria_precio`, tabla para la que
`bodegas_api` solo tiene permiso de lectura en `007_roles.sql`. Para permitir
actualizar precios sin otorgar a la API permiso de insertar auditorías
arbitrarias, un propietario debe aplicar una vez
`api/sql/enable_price_audit.sql`. El script conserva al usuario de conexión en
la auditoría (`session_user`), fija un `search_path` seguro y no se ejecuta
automáticamente ni fue aplicado a ninguna base. Sin aplicarlo, los `PUT` que
cambien el precio fallarán por permisos.

Para ejecución local fuera de Docker, `DB_HOST` debe ser `localhost`. En
Compose, el servicio API reemplaza el host por `db`.
`DB_SSLMODE` controla el cifrado de PostgreSQL; en la nube debe configurarse
como `require` (o el valor exigido por el proveedor). `DB_SSLROOTCERT` es
opcional cuando el proveedor entrega un certificado CA.

## Iniciar con Docker Compose

Copie `.env.example` a `.env` y ejecute
desde la raíz del repositorio:

```powershell
docker compose up
```

En Compose, el servicio `db-bootstrap` espera a que PostgreSQL esté saludable,
asigna `DB_PASSWORD` al rol `bodegas_api` y habilita la función segura de
auditoría de precios. Esto también corrige volúmenes existentes sin borrar
datos. Para un entorno no local, cambie `DB_PASSWORD` mediante un secreto y no
use la contraseña de ejemplo.

La API queda disponible en `http://localhost:8000`; Swagger UI está en
`http://localhost:8000/docs`. Si necesita reconstruir explícitamente la imagen,
use `docker compose up --build` después de autorizar la ejecución del build.
Se permiten por defecto los orígenes locales `localhost:8080` y
`127.0.0.1:8080` para facilitar el consumo desde HTML/JavaScript.

El servicio `db` conserva su volumen actual `db_data`. Compose no ejecuta el
seed ni borra ese volumen. Las migraciones montadas en
`docker-entrypoint-initdb.d` solo se aplican cuando PostgreSQL inicializa un
volumen vacío.

## Ejecutar localmente sin Docker

Después de autorizar la instalación de dependencias, desde la raíz:

```powershell
python -m pip install -r api\requirements.txt
python -m uvicorn api.app.main:app --reload
```

Configure las variables de conexión en el entorno de la terminal antes de
iniciar Uvicorn; por ejemplo:

```powershell
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_NAME = "bodegas_atuel"
$env:DB_USER = "bodegas_api"
$env:DB_PASSWORD = "<contraseña ya configurada para bodegas_api>"
python -m uvicorn api.app.main:app --reload
```

La aplicación lee variables del proceso; no carga `.env` automáticamente.

## Rutas

| Método | Ruta | Uso |
|---|---|---|
| GET | `/salud` | Comprueba la conexión a PostgreSQL |
| GET | `/vinos` | Lista paginada; filtros `tipo`, `id_cepa`, `bodega` (razón social exacta) y `anada` |
| GET | `/vinos/{cod_vino}` | Detalle, cepas, porcentajes, maridajes y stock total |
| POST, PUT, DELETE | `/vinos`, `/vinos/{cod_vino}` | Alta, modificación completa y baja |
| GET | `/clientes` | Lista paginada |
| GET | `/clientes/{id_cliente}` | Consulta un cliente y sus datos de subtipo |
| POST, PUT, DELETE | `/clientes`, `/clientes/{id_cliente}` | CRUD de socios, distribuidores y exportadores |
| POST | `/comprobantes` | Crea una venta completa en una transacción |
| GET | `/comprobantes/{nro_comprobante}` | Consulta cabecera, renglones y total calculado por la base |
| POST | `/transferencias` | Crea una transferencia |
| POST | `/transferencias/{nro_transferencia}/renglones` | Agrega un renglón |
| POST | `/transferencias/{nro_transferencia}/terminar` | Termina la confección |
| POST | `/transferencias/{nro_transferencia}/procesar` | Invoca `sp_procesar_transferencia` |
| POST | `/ingresos` | Crea un ingreso |
| POST | `/ingresos/{cod_ingreso}/renglones` | Agrega un renglón |
| POST | `/ingresos/{cod_ingreso}/terminar` | Termina la confección |
| POST | `/ingresos/{cod_ingreso}/procesar` | Invoca `sp_procesar_ingreso` |
| GET | `/reportes/top-vinos` | Ranking de ventas de vinos |
| GET | `/reportes/ventas-por-sala` | Ventas netas del último trimestre |
| GET | `/reportes/vinos-sin-stock?id_sala=1` | Vinos sin stock local y con stock central |
| GET | `/reportes/transportista-activo` | Transportistas con mayor actividad del último mes |
| GET | `/reportes/trazabilidad/{cod_vino}` | Ingresos, transferencias, ventas y auditoría de precio |
| GET | `/cepas` | Catálogo de cepas para formularios del frontend |
| GET | `/maridajes` | Catálogo de maridajes para formularios del frontend |
| GET | `/bodegas` | Catálogo de bodegas para formularios del frontend |
| GET | `/salas` | Catálogo de salas de venta para formularios y reportes |

`/reportes/trazabilidad/{cod_vino}` no atribuye lotes de uva a un vino: el
esquema existente no contiene esa relación. No se modificó el modelo anterior.

## Errores HTTP

La API traduce SQLSTATE a respuestas HTTP: `23505` y `23503` a 409; `23514` y
`23502` a 422; errores de reglas `P0001` a 409; `22P02` a 400; y errores de
serialización/deadlock (`40001`, `40P01`) a 503 con `Retry-After: 1`. Stock
insuficiente usa 409 para cumplir el criterio de aceptación. Las operaciones
de varios pasos usan transacciones explícitas y revierten los cambios ante
fallos.

## Pruebas

Las pruebas PostgreSQL requieren un servidor de pruebas separado. El perfil
`test` crea `bodegas_atuel_test` en el volumen `db_test_data`, independiente
del volumen principal:

```powershell
docker compose --profile test up -d db-test
python -m pip install -r api\requirements-dev.txt
python -m pytest api\tests
```

La suite verifica la parametrización y el mapeo de SQLSTATE; contra la base
de pruebas también comprueba precio negativo, venta sin stock (incluido el
rollback de la cabecera) y procesamiento prematuro de una transferencia. La
fixture rechaza cualquier base cuyo nombre no termine en `_test`. Las pruebas
no cargan el seed y limpian los registros propios al terminar.

No ejecutar `docker compose down -v`: eliminaría volúmenes persistentes.
