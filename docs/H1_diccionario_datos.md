# Diccionario de Datos - Bodegas del Atuel

## 1. Tipos de Datos Personalizados (ENUMs y Dominios)

Antes de las tablas, se definen los tipos de datos propios de la base de datos para restringir valores, cumpliendo la regla de que los estados y tipos no sean texto libre.

* **`estado_documento` (ENUM):** Valores permitidos: `'en_confeccion'`, `'terminado'`, `'procesado'`.


* **`tipo_cepa` (ENUM):** Valores permitidos: `'tinta'`, `'blanca'`.


* **`tipo_vino` (ENUM):** Valores permitidos: `'tinto'`, `'blanco'`, `'rosado'`, `'espumante'`.


* **`tipo_cliente_enum` (ENUM):** Valores permitidos: `'socio'`, `'distribuidor'`, `'exportador'`.


* **`cuit_dom` (DOMAIN):** `CHAR(11)`. Restringe el formato para CUITs a 11 dígitos numéricos sin guiones.



**Tabla: FINCA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_finca` | `SERIAL` | NO | PK | Identificador autogenerado de la finca. |
| `nombre` | `VARCHAR(100)` | NO |  | Nombre de la finca. |
| `superficie_ha` | `NUMERIC(8,2)` | NO |  | Superficie total de la finca en hectáreas. |
| `departamento` | `VARCHAR(100)` | NO |  | Departamento geográfico en Mendoza. |
| `provincia` | `VARCHAR(100)` | NO |  | Provincia de ubicación (ej. Mendoza). |

**Tabla: CEPA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_cepa` | `SERIAL` | NO | PK | Identificador de la cepa. |
| `nombre` | `VARCHAR(50)` | NO |  | Nombre de la variedad (ej. Malbec). |
| `tipo` | `tipo_cepa` | NO |  | Tipo de uva (tinta o blanca).

 |

**Tabla: PARCELA** (Entidad Débil)

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_finca` | `INT` | NO | PK, FK | Finca a la que pertenece.

 |
| `nro_parcela` | `INT` | NO | PK | Número identificador dentro de la finca.

 |
| `superficie` | `NUMERIC(8,2)` | NO |  | Superficie de la parcela. |
| `anio_plantacion` | `INT` | NO |  | Año en que se plantó la vid. |
| `id_cepa` | `INT` | NO | FK | Cepa plantada en esta parcela (FK a CEPA). |

**Tabla: LOTE_UVA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `nro_lote` | `SERIAL` | NO | PK | Número único del lote cosechado. |
| `anio_campana` | `INT` | NO |  | Año de la campaña de cosecha. |
| `fecha_cosecha` | `DATE` | NO |  | Fecha exacta de la cosecha. |
| `kilos` | `NUMERIC(10,2)` | NO |  | Kilos totales obtenidos. |
| `id_finca` | `INT` | NO | FK | Finca de origen (FK a PARCELA). |
| `nro_parcela` | `INT` | NO | FK | Parcela cosechada (FK a PARCELA). |
| `cuit_bodega` | `cuit_dom` | NO | FK | Bodega de destino (FK a BODEGA). |

**Tabla: ANALISIS_CALIDAD**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_analisis` | `SERIAL` | NO | PK | ID del análisis de laboratorio. |
| `fecha` | `DATE` | NO |  | Fecha en que se realizó el análisis. |
| `brix` | `NUMERIC(5,2)` | NO |  | Grado Brix del mosto. |
| `ph` | `NUMERIC(4,2)` | NO |  | Nivel de pH. |
| `acidez` | `NUMERIC(5,2)` | NO |  | Acidez total en g/L.

 |
| `nro_lote` | `INT` | NO | FK | Lote analizado (FK a LOTE_UVA). |



**Tabla: BODEGA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cuit` | `cuit_dom` | NO | PK | CUIT de la bodega. |
| `razon_social` | `VARCHAR(150)` | NO |  | Razón social legal. |
| `domicilio` | `VARCHAR(200)` | NO |  | Dirección física de la bodega. |

**Tabla: VINO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_vino` | `SERIAL` | NO | PK | Código único del producto.

 |
| `nombre` | `VARCHAR(100)` | NO |  | Nombre comercial del vino. |
| `tipo` | `tipo_vino` | NO |  | Clasificación del vino.

 |
| `anada` | `INT` | NO |  | Año de elaboración de la cosecha. |
| `volumen_ml` | `INT` | NO |  | Presentación en mililitros. |
| `graduacion` | `NUMERIC(4,2)` | NO |  | Porcentaje de graduación alcohólica. |
| `precio` | `NUMERIC(10,2)` | NO |  | Precio de venta general. No usa FLOAT.

 |
| `cuit_bodega` | `cuit_dom` | NO | FK | Bodega elaboradora (FK a BODEGA). |

**Tabla: COMPOSICION**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_vino` | `INT` | NO | PK, FK | Vino compuesto (FK a VINO). |
| `id_cepa` | `INT` | NO | PK, FK | Cepa integrada (FK a CEPA). |
| `porcentaje` | `NUMERIC(5,2)` | NO |  | Porcentaje de corte de la cepa. |

**Tabla: MARIDAJE**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_maridaje` | `SERIAL` | NO | PK | ID único de sugerencia. |
| `nombre` | `VARCHAR(100)` | NO |  | Tipo de comida (ej. Carnes rojas).

 |
| `temp_servicio` | `NUMERIC(4,1)` | NO |  | Temperatura en °C recomendada. |

**Tabla: VINO_MARIDAJE**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_vino` | `INT` | NO | PK, FK | Vino evaluado (FK a VINO). |
| `id_maridaje` | `INT` | NO | PK, FK | Maridaje asociado (FK a MARIDAJE). |

**Tabla: AUDITORIA_PRECIO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_auditoria` | `SERIAL` | NO | PK | ID del registro histórico. |
| `cod_vino` | `INT` | NO | FK | Vino modificado (FK a VINO). |
| `precio_anterior` | `NUMERIC(10,2)` | NO |  | Precio antes del cambio. |
| `precio_nuevo` | `NUMERIC(10,2)` | NO |  | Precio actualizado. |
| `fecha_hora` | `TIMESTAMP` | NO |  | Momento exacto del cambio. |
| `usuario` | `VARCHAR(50)` | NO |  | Usuario de base de datos que hizo el UPDATE. |



**Tabla: LOCALIDAD**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `codigo_postal` | `VARCHAR(20)` | NO | PK | CP de la localidad. |
| `nombre` | `VARCHAR(100)` | NO |  | Nombre de la localidad. |
| `provincia` | `VARCHAR(100)` | NO |  | Provincia a la que pertenece. |
| `encargado_regional` | `VARCHAR(150)` | NO |  | Responsable comercial de la zona. |

**Tabla: SALA_VENTA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_sala` | `SERIAL` | NO | PK | ID único de sucursal. |
| `calle` | `VARCHAR(150)` | NO |  | Calle de ubicación. |
| `numero` | `VARCHAR(20)` | NO |  | Número o altura en la calle. |
| `dia_cierre` | `VARCHAR(20)` | NO |  | Día de la semana que no abre. |
| `codigo_postal` | `VARCHAR(20)` | NO | FK | CP de la sucursal (FK a LOCALIDAD). |

**Tabla: EMPLEADO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cuit` | `cuit_dom` | NO | PK | CUIT del empleado. |
| `nombre` | `VARCHAR(150)` | NO |  | Nombre completo. |
| `fecha_ingreso` | `DATE` | NO |  | Fecha de inicio laboral. |
| `salario` | `NUMERIC(12,2)` | NO |  | Salario actual sin coma flotante.

 |
| `id_sala` | `INT` | NO | FK | Sala donde trabaja (FK a SALA_VENTA). |

**Tabla: STOCK_DEPOSITO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_vino` | `INT` | NO | PK, FK | Vino en depósito central (FK a VINO). |
| `cantidad` | `INT` | NO |  | Cantidad total de botellas disponibles. |

**Tabla: STOCK_SALA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_sala` | `INT` | NO | PK, FK | Sucursal del stock (FK a SALA_VENTA). |
| `cod_vino` | `INT` | NO | PK, FK | Vino almacenado (FK a VINO). |
| `cantidad` | `INT` | NO |  | Botellas disponibles en esa sala. |

**Tabla: TRANSPORTISTA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_transportista` | `SERIAL` | NO | PK | ID de la empresa de transporte. |
| `razon_social` | `VARCHAR(150)` | NO |  | Nombre de la empresa. |
| `cuit` | `cuit_dom` | NO |  | CUIT del transportista. |
| `email` | `VARCHAR(100)` | NO |  | Correo de contacto. |
| `telefono` | `VARCHAR(50)` | NO |  | Número de teléfono. |
| `domicilio` | `VARCHAR(200)` | NO |  | Dirección legal. |

**Tabla: TRANSPORTISTA_LOCALIDAD**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_transportista` | `INT` | NO | PK, FK | Empresa de transporte (FK). |
| `codigo_postal` | `VARCHAR(20)` | NO | PK, FK | Localidad cubierta (FK). |

**Tabla: INGRESO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_ingreso` | `SERIAL` | NO | PK | Código del documento de ingreso. |
| `fecha` | `DATE` | NO |  | Fecha del traslado. |
| `estado` | `estado_doc...` | NO |  | Estado lógico del proceso (ENUM).

 |
| `cod_transportista` | `INT` | NO | FK | Logística a cargo (FK a TRANSPORTISTA). |
| `cuit_bodega` | `cuit_dom` | NO | FK | Bodega emisora (FK a BODEGA). |

**Tabla: RENGLON_INGRESO**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_ingreso` | `INT` | NO | PK, FK | Documento cabecera (FK a INGRESO). |
| `cod_vino` | `INT` | NO | PK, FK | Botellas ingresadas (FK a VINO). |
| `cantidad` | `INT` | NO |  | Unidades transportadas del vino. |

**Tabla: TRANSFERENCIA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `nro_transferencia` | `SERIAL` | NO | PK | Número de la solicitud. |
| `fecha_confeccion` | `DATE` | NO |  | Fecha en la que se armó. |
| `estado` | `estado_doc...` | NO |  | Estado de la transferencia (ENUM).

 |
| `id_sala` | `INT` | NO | FK | Sala solicitante (FK a SALA_VENTA). |

**Tabla: RENGLON_TRANSFERENCIA**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `nro_transferencia` | `INT` | NO | PK, FK | Documento cabecera (FK). |
| `cod_vino` | `INT` | NO | PK, FK | Vino solicitado (FK). |
| `cantidad` | `INT` | NO |  | Cantidad de botellas requeridas. |



**Tabla: CLIENTE**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_cliente` | `SERIAL` | NO | PK | ID general de cliente. |
| `razon_social` | `VARCHAR(150)` | NO |  | Nombre, apellido o empresa del cliente.

 |
| `tipo_doc` | `VARCHAR(10)` | NO |  | DNI, CUIT, PASAPORTE, etc. |
| `nro_doc` | `VARCHAR(50)` | NO |  | Número de documento. |
| `direccion` | `VARCHAR(200)` | NO |  | Dirección de facturación. |
| `localidad` | `VARCHAR(100)` | NO |  | Localidad del cliente. |
| `fecha_alta` | `DATE` | NO |  | Fecha en que se registró. |
| `tipo_cliente` | `tipo_cliente_enum` | NO |  | Subtipo de la jerarquía.

 |

**Tabla: DISTRIBUIDOR**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_cliente` | `INT` | NO | PK, FK | ID de cliente base (FK a CLIENTE). |
| `zona_cobertura` | `VARCHAR(150)` | NO |  | Zona donde opera el distribuidor. |
| `nro_habilitacion` | `VARCHAR(50)` | NO |  | N° de habilitación comercial. |

**Tabla: EXPORTADOR**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `id_cliente` | `INT` | NO | PK, FK | ID de cliente base (FK a CLIENTE). |
| `pais_destino` | `VARCHAR(100)` | NO |  | Principal país donde exporta. |

**Tabla: PERMISO_EXPORTACION**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `cod_permiso` | `SERIAL` | NO | PK | Código del permiso legal. |
| `fecha_emision` | `DATE` | NO |  | Expedición del documento. |
| `fecha_vencimiento` | `DATE` | NO |  | Caducidad del documento. |
| `id_cliente` | `INT` | NO | FK | Exportador dueño (FK a EXPORTADOR). |

**Tabla: COMPROBANTE**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `nro_comprobante` | `SERIAL` | NO | PK | Número correlativo de la venta. |
| `fecha` | `DATE` | NO |  | Fecha de emisión. |
| `id_cliente` | `INT` | NO | FK | Cliente comprador (FK a CLIENTE). |
| `id_sala` | `INT` | NO | FK | Sala de operación (FK a SALA_VENTA). |

**Tabla: RENGLON_COMPROBANTE**

| Columna | Tipo de Dato | Nulo | Restricción | Descripción |
| --- | --- | --- | --- | --- |
| `nro_comprobante` | `INT` | NO | PK, FK | Cabecera (FK a COMPROBANTE). |
| `cod_vino` | `INT` | NO | PK, FK | Vino vendido (FK a VINO). |
| `cantidad` | `INT` | NO |  | Unidades despachadas. |
| `precio_unitario` | `NUMERIC(10,2)` | NO |  | Precio histórico al momento de la venta. |

