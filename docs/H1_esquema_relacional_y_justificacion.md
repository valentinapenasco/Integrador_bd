### 1. Esquema Relacional

**Módulo 1: Campo y Producción**

* **FINCA** (**id_finca**, nombre, superficie_ha, departamento, provincia)
* **CEPA** (**id_cepa**, nombre, tipo)
* **PARCELA** (**id_finca** [FK a FINCA], **nro_parcela**, superficie, anio_plantacion, id_cepa [FK a CEPA])
* **LOTE_UVA** (**nro_lote**, anio_campana, fecha_cosecha, kilos, id_finca [FK a PARCELA], nro_parcela [FK a PARCELA], cuit_bodega [FK a BODEGA])
* **ANALISIS_CALIDAD** (**id_analisis**, fecha, brix, ph, acidez, nro_lote [FK a LOTE_UVA])

**Módulo 2: Bodegas y Vinos**

* **BODEGA** (**cuit**, razon_social, domicilio)
* **VINO** (**cod_vino**, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega [FK a BODEGA])
* **COMPOSICION** (**cod_vino** [FK a VINO], **id_cepa** [FK a CEPA], porcentaje)
* **MARIDAJE** (**id_maridaje**, nombre, temp_servicio)
* **VINO_MARIDAJE** (**cod_vino** [FK a VINO], **id_maridaje** [FK a MARIDAJE])
* **AUDITORIA_PRECIO** (**id_auditoria**, cod_vino [FK a VINO], precio_anterior, precio_nuevo, fecha_hora, usuario)

**Módulo 3: Infraestructura, Logística y Stock**

* **LOCALIDAD** (**codigo_postal**, nombre, provincia, encargado_regional)
* **SALA_VENTA** (**id_sala**, calle, numero, dia_cierre, codigo_postal [FK a LOCALIDAD])
* **EMPLEADO** (**cuit**, nombre, fecha_ingreso, salario, id_sala [FK a SALA_VENTA])
* **STOCK_DEPOSITO** (**cod_vino** [FK a VINO], cantidad)
* **STOCK_SALA** (**id_sala** [FK a SALA_VENTA], **cod_vino** [FK a VINO], cantidad)
* **TRANSPORTISTA** (**cod_transportista**, razon_social, cuit, email, telefono, domicilio)
* **TRANSPORTISTA_LOCALIDAD** (**cod_transportista** [FK a TRANSPORTISTA], **codigo_postal** [FK a LOCALIDAD])
* **INGRESO** (**cod_ingreso**, fecha, estado, cod_transportista [FK a TRANSPORTISTA], cuit_bodega [FK a BODEGA])
* **RENGLON_INGRESO** (**cod_ingreso** [FK a INGRESO], **cod_vino** [FK a VINO], cantidad)
* **TRANSFERENCIA** (**nro_transferencia**, fecha_confeccion, estado, id_sala_solicitante [FK a SALA_VENTA])
* **RENGLON_TRANSFERENCIA** (**nro_transferencia** [FK a TRANSFERENCIA], **cod_vino** [FK a VINO], cantidad)

**Módulo 4: Clientes y Ventas**

* **CLIENTE** (**id_cliente**, razon_social, tipo_doc, nro_doc, direccion, localidad, fecha_alta, tipo_cliente)
* **DISTRIBUIDOR** (**id_cliente** [FK a CLIENTE], zona_cobertura, nro_habilitacion)
* **EXPORTADOR** (**id_cliente** [FK a CLIENTE], pais_destino)
* **PERMISO_EXPORTACION** (**cod_permiso**, fecha_emision, fecha_vencimiento, id_cliente_exportador [FK a EXPORTADOR])
* **COMPROBANTE** (**nro_comprobante**, fecha, id_cliente [FK a CLIENTE], id_sala [FK a SALA_VENTA])
* **RENGLON_COMPROBANTE** (**nro_comprobante** [FK a COMPROBANTE], **cod_vino** [FK a VINO], cantidad, precio_unitario)


### 2. Justificación del Mapeo de la Jerarquía de Clientes

Para resolver la jerarquía "IS-A" del supertipo `CLIENTE` y sus subtipos (`SOCIO`, `DISTRIBUIDOR`, `EXPORTADOR`), existen tres enfoques teóricos documentados. Se implementó la opción de "Crear una relación por cada conjunto de entidades".

* **Justificación:** Se mantiene la tabla principal `CLIENTE` con los atributos comunes (como `razon_social` y `fecha_alta`), y cada subtipo posee una clave foránea proveniente del supertipo (`id_cliente`) con la que se identifica. Esto evita la generación masiva de valores nulos (anomalías) que ocurriría si se unificaran todos los atributos específicos en una única tabla global. Además, permite que la entidad `COMPROBANTE` apunte limpiamente a la tabla unificada `CLIENTE`, y habilita al `EXPORTADOR` a tener su propia relación 1:N externa con `PERMISO_EXPORTACION`.



### 3. Verificación de Normalización hasta 3FN

**Primera Forma Normal (1FN)**

* **Regla:** Todos los atributos deben contener valores atómicos (indivisibles) y no pueden existir grupos repetitivos ni atributos multivaluados.


* **Verificación:** Se independizaron los datos multivaluados en tablas auxiliares (como `COMPOSICION` y `VINO_MARIDAJE`). Todos los atributos derivados definidos en el DER (`antigüedad` en Empleado, y los importes totales en Comprobantes) fueron eliminados del esquema, ya que por teoría no se almacenan.


**Segunda Forma Normal (2FN)**

* **Regla:** La relación debe estar en 1FN y todos los atributos no primos deben depender de toda la clave primaria, eliminando las dependencias parciales.


* **Verificación:** Analizando las tablas con claves compuestas:
* En `COMPOSICION (cod_vino, id_cepa)`, la dependencia funcional es `{cod_vino, id_cepa} -> porcentaje`. El porcentaje no depende solo del vino ni solo de la cepa, sino de ambos conjuntamente.


* En `RENGLON_COMPROBANTE (nro_comprobante, cod_vino)`, los atributos `cantidad` y `precio_unitario` dependen de toda la clave primaria conjunta. No existen dependencias parciales.



**Tercera Forma Normal (3FN)**

* **Regla:** La relación debe estar en 2FN y ningún atributo no clave debe depender de otro atributo no clave, eliminando las dependencias transitivas.


* **Verificación de Dependencias Funcionales Relevantes:**
* `SALA_VENTA -> LOCALIDAD -> ENCARGADO_REGIONAL`: El encargado de la región depende estrictamente de la localidad y no de una sala particular. Si el atributo `encargado_regional` estuviera en `SALA_VENTA`, se generaría una dependencia transitiva (`id_sala -> codigo_postal -> encargado_regional`). Al separar `LOCALIDAD` con su propia clave primaria (`codigo_postal`), la dependencia transitiva desaparece.


* `COMPROBANTE -> CLIENTE -> RAZON_SOCIAL`: La tabla `COMPROBANTE` únicamente almacena la FK `id_cliente`. Almacenar la `razon_social` dentro del comprobante crearía una dependencia transitiva, lo cual se solucionó apuntando al identificador unívoco del cliente.