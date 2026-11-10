# Guion de demo y defensa

## Preparación

1. Confirmar que Docker Desktop está activo.
2. Ejecutar:

   ```powershell
   docker compose up --build
   ```

3. Abrir:
   - Frontend: `http://localhost:8080`
   - Swagger: `http://localhost:8000/docs`
4. Tener disponible la consola para mostrar pruebas SQL y logs.

## Demo sugerida — 10 a 15 minutos

### 1. Arquitectura y modelo — 2 minutos

- Mostrar el [DER](DER.png).
- Explicar la separación entre base, API y frontend.
- Señalar que la API usa `bodegas_api` y no el propietario.
- Aclarar que el frontend no contiene SQL ni calcula stock o importes.

### 2. Catálogo — 2 minutos

- Abrir el catálogo.
- Aplicar filtros por tipo, cepa, bodega y añada.
- Abrir el detalle de un vino.
- Mostrar composición, maridajes y stock total retornados por la API.

### 3. Regla de composición — 2 minutos

- Abrir alta o edición de vino.
- Enviar una composición cuyos porcentajes no sumen 100.
- Mostrar el mensaje devuelto por la API.
- Explicar que la validación se realiza mediante un constraint trigger
  diferido en PostgreSQL.

### 4. Venta y transacción — 3 minutos

- Seleccionar cliente y sala.
- Registrar una venta válida.
- Mostrar el total calculado por el backend.
- Intentar vender más unidades que el stock disponible.
- Mostrar el error de stock insuficiente.
- Explicar que la transacción revierte también la cabecera del comprobante.

### 5. Transferencia — 2 minutos

- Crear una transferencia.
- Agregar un renglón.
- Terminar la confección.
- Procesar la transferencia.
- Explicar las transiciones `en_confeccion -> terminado -> procesado`.

### 6. Tablero — 2 minutos

- Mostrar el ranking de los diez vinos más vendidos.
- Mostrar ventas netas por sala.
- Seleccionar una sala y mostrar vinos sin stock local con stock central.
- Aclarar que los cálculos provienen de consultas de la API y la base.

## Preguntas esperables

### ¿Dónde se calculan los totales?

En las funciones y consultas de PostgreSQL, principalmente
`fn_total_comprobante()`. El frontend solo presenta el valor recibido.

### ¿Cómo se evita vender stock inexistente?

El trigger bloquea la fila de stock con `FOR UPDATE`, valida la cantidad y
descuenta el stock dentro de la misma transacción.

### ¿Por qué la API no usa el usuario propietario?

Para aplicar privilegios mínimos. `bodegas_api` no administra el esquema ni
puede modificar las migraciones.

### ¿Cómo se evita la inyección SQL?

La API utiliza consultas parametrizadas con psycopg. Los filtros del frontend
se envían como parámetros HTTP y nunca se concatenan en las consultas SQL.

### ¿Qué ocurre si una transferencia se procesa antes de terminar?

El procedimiento almacenado rechaza la transición y la API traduce el error a
una respuesta HTTP visible para el usuario.

### ¿Qué se excluyó del alcance?

El despliegue en la nube de la etapa 8, por indicación explícita de la
cátedra. La entrega se reproduce localmente con Docker Compose.

## Evidencia recomendada

Guardar capturas de:

- Frontend iniciado.
- Filtros y detalle de vino.
- Composición inválida.
- Venta exitosa.
- Venta sin stock.
- Transferencia procesada.
- Tablero.
- Swagger `/docs`.

No capturar contraseñas, archivos `.env` ni cadenas de conexión.
