# Trabajo Integrador: Bodegas del Atuel

Sistema de gestión y distribución para la empresa vitivinícola ficticia
“Bodegas del Atuel”. Trabajo Práctico Integrador de Bases de Datos (UTN FRSR
2026).


# Integrantes

1. Albarracín Valentina
2. Pérez Buttini Nicolás
3. Peñasco Valentina

## Alcance

El proyecto cubre las etapas 1 a 7 y la documentación, demo y defensa de la
etapa 9. La etapa 8 de despliegue en la nube queda fuera del alcance por
indicación explícita de la cátedra; la ejecución reproducible se realiza en
local con Docker Compose.

## Requisitos

- Motor de base de datos PostgreSQL 14 o superior en contenedor local
- Acceso a datos Driver nativo (por ejemplo psycopg en Python, pg en Node, JDBC en Java)
- Prohibido ORM y query builders que oculten el SQL
- API REST con JSON, en el lenguaje que elija el grupo
- Documentada con OpenAPI/Swagger o una colección Postman
- Front Libre: HTML/CSS/JS, React, Vue, etc. Consume únicamente la API
- Contenedores Docker y Docker Compose Un solo comando debe levantar base, API y front en local
- Control de versiones Git en GitHub o GitLab Commits de todos los integrantes
- Generación de datos Python con Faker y random (u otra herramienta equivalente) más catálogos reales
- Semilla fija para que sea reproducible
- Modelado draw.io, dbdiagram.io, pgModeler u otra herramienta
- Entregar imagen/PDF y el archivo fuente

## Estructura principal

```text
db/migrations/   Esquema, restricciones, lógica, vistas, roles e índices
db/seed/         Generador reproducible y catálogos
db/tests/        Pruebas de reglas de la base
consultas/       Consignas SQL de la etapa 5
api/             API FastAPI con psycopg, sin ORM
front/           Aplicación React/Vite
docs/            Informes parciales, informe final y guía de demo
```

## Ejecución local completa

1. Copiar `.env.example` como `.env` y revisar los valores locales.
2. Iniciar los servicios:

```powershell
docker compose up --build
```

La primera inicialización aplica automáticamente las migraciones al volumen
vacío. El servicio `db-bootstrap` configura el rol `bodegas_api` y habilita la
auditoría segura de precios. No se debe ejecutar el seed automáticamente al
iniciar el sistema.

URLs locales:

- Frontend: `http://localhost:8080`
- API: `http://localhost:8000`
- OpenAPI/Swagger: `http://localhost:8000/docs`

Para detener los servicios sin borrar datos:

```powershell
docker compose down
```

No ejecutar `docker compose down -v` salvo que se quiera eliminar la base
local y volver a aplicar todas las migraciones.

## Pruebas

Pruebas unitarias de la API:

```powershell
python -m pip install -r api\requirements-dev.txt
python -m pytest api\tests
```

Las pruebas de base requieren el servicio separado:

```powershell
docker compose --profile test up -d db-test
python -m pytest api\tests
```

Las pruebas SQL se ejecutan sobre una base de pruebas vacía y no deben
ejecutarse contra una base con datos que se quiera conservar:

```powershell
Get-Content -Raw .\db\tests\db_tests.sql |
  docker exec -i bodegas_db psql -v ON_ERROR_STOP=1 -U postgres -d bodegas_atuel
```

## Carga reproducible

La carga completa utiliza la semilla `42`, Faker y catálogos reales. Para
autorizarla explícitamente:

```powershell
$env:POSTGRES_HOST = "localhost"
$env:POSTGRES_PORT = "5432"
$env:POSTGRES_DB = "bodegas_atuel"
$env:POSTGRES_USER = "postgres"
$env:POSTGRES_PASSWORD = "postgres"
python .\db\seed\seed.py
```

Para una carga reducida de validación, consultar
[`db/seed/README.md`](db/seed/README.md).

## Documentación por etapa

- [Modelo, esquema y normalización](docs/H1_esquema_relacional_y_justificacion.md)
- [Diccionario de datos](docs/H1_diccionario_datos.md)
- [Integridad y lógica](docs/H2_integridad_y_logica.md)
- [Carga masiva](docs/H3_carga_masiva.md)
- [Índices y rendimiento](docs/H4_indices_y_rendimiento.md)
- [Consultas SQL](docs/H5_consultas_sql.md)
- [API REST](docs/H6_api.md)
- [Frontend](docs/H7_front.md)
- [Informe final](docs/informe_final.md)
- [Guion de demo y defensa](docs/demo_defensa.md)

## API local (Etapa 6)

La API FastAPI/psycopg, sus variables de entorno, documentación y pruebas se
describen en [docs/H6_api.md](docs/H6_api.md). No ejecutar el seed para iniciar
la API.

## Front local (Etapa 7)

El frontend React consume únicamente la API y queda disponible en
`http://localhost:8080`. Para levantar base, API y frontend:

```powershell
docker compose up --build
```

La URL de la API se puede cambiar al construir con `VITE_API_URL`. El front
incluye catálogo, alta y edición de vinos, ventas, transferencias y tablero
de reportes. Los totales, descuentos, estados y existencias son calculados y
validados por la API y la base de datos.

La carpeta local `ejemplo/` se utiliza únicamente como referencia y está
excluida de Git y de los contextos Docker.
