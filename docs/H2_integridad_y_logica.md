# H2 - Integridad y lógica en la base

## Alcance

La etapa 2 agrega las restricciones, funciones, procedimientos, triggers,
vistas y roles exigidos por el enunciado. Las migraciones se aplican en orden,
desde `001_esquema.sql` hasta `007_roles.sql`.

## Trazabilidad de reglas

| Regla | Mecanismo | Archivo | Prueba |
| --- | --- | --- | --- |
| RN-01 | `CHECK` de precio y `UNIQUE` de vino | `002_constraints.sql` | Precio cero |
| RN-02 | FK de sala a localidad y diseño 3FN | `001_esquema.sql` | Localidad inexistente |
| RN-03 | FK `empleado.id_sala` | `001_esquema.sql` | Sala inexistente |
| RN-04 | `UNIQUE (id_finca, nro_parcela, anio_campana)` | `002_constraints.sql` | Cosecha duplicada |
| RN-05 | Constraint trigger diferido | `005_triggers.sql` | Composición que no suma 100 |
| RN-06 | `fn_descuento_cliente` | `003_funciones.sql` | Descuento de socio |
| RN-07 | `CHECK` de fechas del permiso | `002_constraints.sql` | Vencimiento anterior |
| RN-08 | `fn_total_comprobante` | `003_funciones.sql` | Total de comprobante |
| RN-09 | Trigger de stock y `CHECK` de stock | `005_triggers.sql`, `002_constraints.sql` | Venta sin stock |
| RN-10 | Trigger y procedimiento de ingreso | `005_triggers.sql`, `004_procedimientos.sql` | Transición inválida |
| RN-11 | Trigger y procedimiento de transferencia | `005_triggers.sql`, `004_procedimientos.sql` | Fecha/transición inválida |
| RN-12 | Trigger de bloqueo de renglones | `005_triggers.sql` | Renglón en documento terminado |
| RN-13 | Trigger de auditoría de precio | `005_triggers.sql` | Actualización de precio |
| RN-14 | FKs con `ON DELETE RESTRICT` | `001_esquema.sql` | Borrado de entidades con movimientos |
| RN-15 | `CHECK` de cantidades, superficies, kilos y graduación | `002_constraints.sql` | Graduación/precio inválidos |

## Roles

- `bodegas_owner`: propietario lógico de los objetos y rol de administración.
- `bodegas_api`: lectura/escritura de datos, ejecución de funciones y
  procedimientos, sin permisos para modificar el esquema.
- `bodegas_reportes`: solo lectura de las tres vistas.

Las contraseñas de los roles de conexión deben configurarse fuera del
repositorio mediante variables de entorno.

## Concurrencia

La validación de stock en `tr_validar_stock_venta` obtiene la fila de
`stock_sala` mediante `SELECT ... FOR UPDATE`. Por lo tanto, dos ventas
simultáneas del mismo vino en la misma sala se serializan sobre esa fila:

1. La primera transacción bloquea la fila y valida el stock.
2. La segunda transacción espera el desbloqueo.
3. La segunda vuelve a evaluar el stock actualizado y falla si ya no alcanza.

Para demostrarlo se necesitan dos sesiones `psql` conectadas a la misma base,
un vino con una sola unidad disponible y dos inserciones concurrentes en
`renglon_comprobante`. La primera debe confirmar y la segunda debe recibir el
error de stock insuficiente. La prueba debe repetirse con y sin
`SELECT ... FOR UPDATE` y conservar capturas de ambas sesiones.

## Ejecución de pruebas

Sobre una base de pruebas vacía:

```powershell
Get-Content -Raw .\db\tests\db_tests.sql |
  docker exec -i bodegas_db psql -v ON_ERROR_STOP=1 -U postgres -d bodegas_atuel
```

El script contiene casos exitosos y casos esperados de error para las reglas
RN-01 a RN-15.
