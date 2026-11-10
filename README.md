# Trabajo Integrador Bases de datos

Sistema de gestión y distribución para la empresa vitivinícola ficticia 'Bodegas del Atuel'. Trabajo Práctico Integrador - Bases de Datos (UTN FRSR 2026)


# Integrantes:
1. Albarracín Valentina
2. Pérez Buttini Nicolás
3. Peñasco Valentina

# Requisitos
- Motor de base de datos PostgreSQL 14 o superior Local en contenedor y luego en la nube
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

## API local (Etapa 6)

La API FastAPI/psycopg, sus variables de entorno, documentación y pruebas se
describen en [docs/H6_api.md](docs/H6_api.md). No ejecutar el seed para iniciar
la API.
