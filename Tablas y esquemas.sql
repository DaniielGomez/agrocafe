--1. PARCELAS

CREATE TABLE parcelas (
    id_parcela      SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    ubicacion       VARCHAR(150),
    area_hectareas  NUMERIC(10,2),
    altitud_msnm    NUMERIC(6,2),
    fecha_registro  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2. TEMPORADAS

CREATE TABLE temporadas (
    id_temporada    SERIAL PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,      -- ej: "2025-2026"
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE,
    CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- 3. TIPOS_CAFE (variedades)

CREATE TABLE tipos_cafe (
    id_tipo_cafe    SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL,      -- ej: "Arábica", "Robusta", "Caturra"
    descripcion     TEXT
);

-- 4. LOTES_COSECHA
-- Une parcela + temporada + tipo de café

CREATE TABLE lotes_cosecha (
    id_lote                 SERIAL PRIMARY KEY,
    id_parcela              INTEGER NOT NULL REFERENCES parcelas(id_parcela),
    id_temporada            INTEGER NOT NULL REFERENCES temporadas(id_temporada),
    id_tipo_cafe            INTEGER NOT NULL REFERENCES tipos_cafe(id_tipo_cafe),
    fecha_cosecha           DATE NOT NULL,
    cantidad_recolectada_kg NUMERIC(10,2) NOT NULL CHECK (cantidad_recolectada_kg >= 0),
    fecha_registro          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 5. DATOS_AGRONOMICOS
--    Variables agronómicas asociadas a cada lote
--    (relación 1 a 1 con lotes_cosecha, en esta versión)

CREATE TABLE datos_agronomicos (
    id_dato         SERIAL PRIMARY KEY,
    id_lote         INTEGER NOT NULL UNIQUE REFERENCES lotes_cosecha(id_lote),
    clima           VARCHAR(80),
    plagas          VARCHAR(150),
    humedad         NUMERIC(5,2),   -- porcentaje
    rendimiento     NUMERIC(10,2)   -- ej: kg/hectárea, a definir unidad exacta
);

-- 6. CLASIFICACIONES_IA
--    Resultado del modelo K-Means para cada lote

CREATE TABLE clasificaciones_ia (
    id_clasificacion    SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL UNIQUE REFERENCES lotes_cosecha(id_lote),
    numero_cluster      INTEGER NOT NULL,          -- 0, 1, 2, ...
    interpretacion       VARCHAR(50),               -- ej: "Rendimiento alto"
    fecha_analisis      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 7. ALMACENES

CREATE TABLE almacenes (
    id_almacen      SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    ubicacion       VARCHAR(150),
    capacidad_kg    NUMERIC(10,2)
);

-- 8. INVENTARIO_EXISTENCIAS
--    Existencia actual de un lote en un almacén

CREATE TABLE inventario_existencias (
    id_existencia       SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL REFERENCES lotes_cosecha(id_lote),
    id_almacen          INTEGER NOT NULL REFERENCES almacenes(id_almacen),
    cantidad_disponible NUMERIC(10,2) NOT NULL CHECK (cantidad_disponible >= 0),
    stock_minimo        NUMERIC(10,2) NOT NULL DEFAULT 0,
    fecha_ingreso        DATE NOT NULL,
    UNIQUE (id_lote, id_almacen)
);

-- 9. MOVIMIENTOS_INVENTARIO
--    Trazabilidad: entradas, salidas, traslados, mermas

CREATE TABLE movimientos_inventario (
    id_movimiento       SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL REFERENCES lotes_cosecha(id_lote),
    id_almacen_origen   INTEGER REFERENCES almacenes(id_almacen),   -- NULL si es entrada nueva
    id_almacen_destino  INTEGER REFERENCES almacenes(id_almacen),   -- NULL si es salida/merma final
    tipo_movimiento     VARCHAR(20) NOT NULL CHECK (
                            tipo_movimiento IN ('entrada','salida','traslado','merma')
                        ),
    cantidad            NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
    fecha_movimiento    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Índices sugeridos (básicos, sobre las FK más consultadas)

CREATE INDEX idx_lotes_parcela ON lotes_cosecha(id_parcela);
CREATE INDEX idx_lotes_temporada ON lotes_cosecha(id_temporada);
CREATE INDEX idx_existencias_lote ON inventario_existencias(id_lote);
CREATE INDEX idx_movimientos_lote ON movimientos_inventario(id_lote);