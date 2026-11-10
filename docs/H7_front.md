# Etapa 7: Front

El frontend se encuentra en `front/` y está implementado con React y Vite.
Consume exclusivamente la API REST en `VITE_API_URL`; no contiene SQL ni
reimplementa cálculos de importes, descuentos o stock.

## Ejecución

Desde la raíz del repositorio:

```powershell
docker compose up --build
```

La interfaz queda disponible en `http://localhost:8080` y la API en
`http://localhost:8000/docs`. También se puede cambiar el puerto con
`FRONT_PORT` y la URL de API con `VITE_API_URL`.

## Pantallas

- Catálogo paginado, con filtros, detalle, composición y maridajes.
- Alta y edición de vinos.
- Nueva venta con total retornado por el backend.
- Transferencias con controles según el estado de la base.
- Tablero con ranking, ventas por sala y vinos sin stock local.

Los errores de las reglas de negocio se presentan usando el campo `detail`
retornado por la API. Para la evidencia de aceptación se deben probar una
composición que no sume 100 % y una venta con stock insuficiente, verificando
que la API revierte la operación.
