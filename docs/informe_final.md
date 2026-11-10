# Informe final — Bodegas del Atuel

## 1. Introducción y alcance

El sistema administra la producción vitivinícola, el catálogo de vinos, el
stock, la logística, los clientes y las ventas de Bodegas del Atuel.

El alcance implementado comprende las etapas 1 a 7 y la documentación final de
la etapa 9. La etapa 8 de despliegue en la nube se excluye por indicación
explícita de la cátedra. La ejecución demostrable se realiza localmente con
PostgreSQL, FastAPI, React y Docker Compose.

## 2. Modelo de datos

El modelo entidad-relación, el esquema relacional, la normalización y las
decisiones de diseño se encuentran en:

- [DER](DER.png)
- [Esquema relacional y justificación](H1_esquema_relacional_y_justificacion.md)
- [Diccionario de datos](H1_diccionario_datos.md)
- [Migración de esquema](../db/migrations/001_esquema.sql)

El diseño separa los módulos de producción, bodegas y vinos, infraestructura y
stock, y clientes y ventas. Las relaciones multivaluadas se modelan mediante
tablas intermedias, y las claves foráneas preservan las dependencias entre
entidades.

## 3. Integridad y lógica en la base

Las restricciones, funciones, procedimientos, triggers, vistas, roles y
pruebas están documentados en [H2 — Integridad y lógica](H2_integridad_y_logica.md).

La tabla de trazabilidad relaciona cada regla RN-01 a RN-15 con su mecanismo y
su prueba. Entre las reglas demostradas se incluyen:

- Precio y cantidades válidas.
- Composición que suma 100 %.
- Transiciones de ingresos y transferencias.
- Bloqueo de renglones terminados.
- Auditoría de cambios de precio.
- Descuento de stock y rechazo de ventas sin existencias.
- Concurrencia mediante bloqueo de filas.

## 4. Carga masiva

La carga usa `Faker`, catálogos CSV, una semilla fija y operaciones por lotes.
La implementación y los controles se documentan en
[H3 — Carga masiva](H3_carga_masiva.md).

La configuración completa supera los mínimos de volumen de la consigna. La
semilla, los conteos y los parámetros de carga se pueden reproducir mediante
[db/seed/README.md](../db/seed/README.md).

## 5. Índices y rendimiento

La etapa de índices incluye índices de claves foráneas, compuesto, parcial, de
expresión y BRIN. La comparación de planes, buffers, tiempos, costo de
escritura y el caso de baja selectividad se encuentra en
[H4 — Índices y rendimiento](H4_indices_y_rendimiento.md).

La evidencia completa de `EXPLAIN (ANALYZE, BUFFERS)` se conserva en
[resultado_etapa4.txt](../db/performance/resultado_etapa4.txt).

## 6. Consultas SQL

Las consignas U1-U6, I1-I6, D1-D6 y S1-S12 están implementadas en:

- [UPDATE](../consultas/update.sql)
- [INSERT](../consultas/insert.sql)
- [DELETE](../consultas/delete.sql)
- [SELECT](../consultas/select.sql)

La explicación de las consultas, el uso de CTE, ventanas, subconsultas,
división relacional y `NOT EXISTS` está en
[H5 — Consultas SQL](H5_consultas_sql.md). Las modificaciones se muestran
dentro de transacciones y terminan con `ROLLBACK` para las demostraciones.

## 7. API y frontend

La API usa FastAPI y el driver nativo psycopg, con SQL parametrizado y sin ORM.
La conexión utiliza el rol `bodegas_api`, mientras PostgreSQL conserva las
reglas de negocio.

La arquitectura, endpoints, errores y pruebas están documentados en
[H6 — API REST](H6_api.md). El frontend React consume únicamente la API y sus
cinco pantallas están descritas en
[H7 — Front](H7_front.md).

Los casos clave de la demo son:

1. Composición inválida de un vino.
2. Venta sin stock.
3. Transferencia con transición de estado.
4. Total de venta calculado por la base.
5. Ranking y ventas por sala.

## 8. Ejecución reproducible

Desde la raíz:

```powershell
docker compose up --build
```

Luego abrir `http://localhost:8080`. La API está disponible en
`http://localhost:8000/docs`.

Las pruebas y la carga explícita están documentadas en
[README.md](../README.md). No se incluyen credenciales reales ni archivos de
backup en el repositorio.

## 9. Decisiones y limitaciones conocidas

- La base no relaciona directamente lotes de uva con vinos, por lo que la
  trazabilidad de la API cubre ingresos, transferencias, ventas y auditoría de
  precios.
- El total del comprobante se calcula mediante la función de la base; no se
  almacena como columna derivada.
- La etapa 8 no forma parte de esta entrega por instrucción explícita de la
  cátedra.
