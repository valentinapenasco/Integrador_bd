HITO 1: ESQUEMA FÍSICO

CREATE TYPE estado_documento AS ENUM ('en_confeccion', 'terminado', 'procesado');
CREATE TYPE tipo_cepa AS ENUM ('tinta', 'blanca');
CREATE TYPE tipo_vino AS ENUM ('tinto', 'blanco', 'rosado', 'espumante');
CREATE TYPE tipo_cliente_enum AS ENUM ('socio', 'distribuidor', 'exportador');

CREATE DOMAIN cuit_dom AS CHAR(11);


CREATE TABLE finca (
    id_finca SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    superficie_ha NUMERIC(8,2) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL
);

CREATE TABLE cepa (
    id_cepa SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo tipo_cepa NOT NULL
);

CREATE TABLE parcela (
    id_finca INT NOT NULL REFERENCES finca(id_finca),
    nro_parcela INT NOT NULL,
    superficie NUMERIC(8,2) NOT NULL,
    anio_plantacion INT NOT NULL,
    id_cepa INT NOT NULL REFERENCES cepa(id_cepa),
    PRIMARY KEY (id_finca, nro_parcela)
);

CREATE TABLE bodega (
    cuit cuit_dom PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    domicilio VARCHAR(200) NOT NULL
);

CREATE TABLE lote_uva (
    nro_lote SERIAL PRIMARY KEY,
    anio_campana INT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos NUMERIC(10,2) NOT NULL,
    id_finca INT NOT NULL,
    nro_parcela INT NOT NULL,
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit),
    FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela)
);

CREATE TABLE analisis_calidad (
    id_analisis SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    brix NUMERIC(5,2) NOT NULL,
    ph NUMERIC(4,2) NOT NULL,
    acidez NUMERIC(5,2) NOT NULL,
    nro_lote INT NOT NULL REFERENCES lote_uva(nro_lote)
);



CREATE TABLE vino (
    cod_vino SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    tipo tipo_vino NOT NULL,
    anada INT NOT NULL,
    volumen_ml INT NOT NULL,
    graduacion NUMERIC(4,2) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit)
);

CREATE TABLE composicion (
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    id_cepa INT NOT NULL REFERENCES cepa(id_cepa),
    porcentaje NUMERIC(5,2) NOT NULL,
    PRIMARY KEY (cod_vino, id_cepa)
);

CREATE TABLE maridaje (
    id_maridaje SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    temp_servicio NUMERIC(4,1) NOT NULL
);

CREATE TABLE vino_maridaje (
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    id_maridaje INT NOT NULL REFERENCES maridaje(id_maridaje),
    PRIMARY KEY (cod_vino, id_maridaje)
);

CREATE TABLE auditoria_precio (
    id_auditoria SERIAL PRIMARY KEY,
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    precio_anterior NUMERIC(10,2) NOT NULL,
    precio_nuevo NUMERIC(10,2) NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    usuario VARCHAR(50) NOT NULL
);


CREATE TABLE localidad (
    codigo_postal VARCHAR(20) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    provincia VARCHAR(100) NOT NULL,
    encargado_regional VARCHAR(150) NOT NULL
);

CREATE TABLE sala_venta (
    id_sala SERIAL PRIMARY KEY,
    calle VARCHAR(150) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    dia_cierre VARCHAR(20) NOT NULL,
    codigo_postal VARCHAR(20) NOT NULL REFERENCES localidad(codigo_postal)
);

CREATE TABLE empleado (
    cuit cuit_dom PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    salario NUMERIC(12,2) NOT NULL,
    id_sala INT NOT NULL REFERENCES sala_venta(id_sala)
);

CREATE TABLE stock_deposito (
    cod_vino INT PRIMARY KEY REFERENCES vino(cod_vino),
    cantidad INT NOT NULL
);

CREATE TABLE stock_sala (
    id_sala INT NOT NULL REFERENCES sala_venta(id_sala),
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    cantidad INT NOT NULL,
    PRIMARY KEY (id_sala, cod_vino)
);

CREATE TABLE transportista (
    cod_transportista SERIAL PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    cuit cuit_dom NOT NULL,
    email VARCHAR(100) NOT NULL,
    telefono VARCHAR(50) NOT NULL,
    domicilio VARCHAR(200) NOT NULL
);

CREATE TABLE transportista_localidad (
    cod_transportista INT NOT NULL REFERENCES transportista(cod_transportista),
    codigo_postal VARCHAR(20) NOT NULL REFERENCES localidad(codigo_postal),
    PRIMARY KEY (cod_transportista, codigo_postal)
);

CREATE TABLE ingreso (
    cod_ingreso SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    estado estado_documento NOT NULL,
    cod_transportista INT NOT NULL REFERENCES transportista(cod_transportista),
    cuit_bodega cuit_dom NOT NULL REFERENCES bodega(cuit)
);

CREATE TABLE renglon_ingreso (
    cod_ingreso INT NOT NULL REFERENCES ingreso(cod_ingreso),
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    cantidad INT NOT NULL,
    PRIMARY KEY (cod_ingreso, cod_vino)
);

CREATE TABLE transferencia (
    nro_transferencia SERIAL PRIMARY KEY,
    fecha_confeccion DATE NOT NULL,
    estado estado_documento NOT NULL,
    id_sala_solicitante INT NOT NULL REFERENCES sala_venta(id_sala)
);

CREATE TABLE renglon_transferencia (
    nro_transferencia INT NOT NULL REFERENCES transferencia(nro_transferencia),
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    cantidad INT NOT NULL,
    PRIMARY KEY (nro_transferencia, cod_vino)
);



CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    nro_doc VARCHAR(50) NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    localidad VARCHAR(100) NOT NULL,
    fecha_alta DATE NOT NULL,
    tipo_cliente tipo_cliente_enum NOT NULL
);

CREATE TABLE distribuidor (
    id_cliente INT PRIMARY KEY REFERENCES cliente(id_cliente),
    zona_cobertura VARCHAR(150) NOT NULL,
    nro_habilitacion VARCHAR(50) NOT NULL
);

CREATE TABLE exportador (
    id_cliente INT PRIMARY KEY REFERENCES cliente(id_cliente),
    pais_destino VARCHAR(100) NOT NULL
);

CREATE TABLE permiso_exportacion (
    cod_permiso SERIAL PRIMARY KEY,
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    id_cliente_exportador INT NOT NULL REFERENCES exportador(id_cliente)
);

CREATE TABLE comprobante (
    nro_comprobante SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    id_cliente INT NOT NULL REFERENCES cliente(id_cliente),
    id_sala INT NOT NULL REFERENCES sala_venta(id_sala)
);

CREATE TABLE renglon_comprobante (
    nro_comprobante INT NOT NULL REFERENCES comprobante(nro_comprobante),
    cod_vino INT NOT NULL REFERENCES vino(cod_vino),
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (nro_comprobante, cod_vino)
);