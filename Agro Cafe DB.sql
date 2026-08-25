-- AGROCAFÉ - Base de Datos Final (Versión de Entrega)
-- Motor: PostgreSQL 14+

-- Contenido de este script:
--   1. Catálogos (roles, usuarios, parcelas, temporadas, tipos_cafe,
--      almacenes, catalogo_tipos_movimiento)
--   2. Producción (lotes_cosecha, datos_agronomicos)
--   3. Motor de IA (analisis_ejecuciones, clasificaciones_ia)
--   4. Inventario (inventario_existencias, movimientos_inventario,
--      alertas_inventario)
--   5. Auditoría (bitacora_operaciones)
--   6. Índices
--   7. Funciones y Triggers (mantenimiento automático de datos)
--   8. Vistas (soporte directo para el dashboard)
--   9. Comentarios de documentación (COMMENT ON)
--  10. Apéndice: roles de acceso a nivel de base de datos (referencia)

-- roles

CREATE TABLE roles (
    id_rol          SERIAL PRIMARY KEY,
    nombre          VARCHAR(40)  NOT NULL UNIQUE,   -- ej: 'administrador', 'operador', 'consulta'
    descripcion     VARCHAR(150)
);

-- usuarios

CREATE TABLE usuarios (
    id_usuario          SERIAL PRIMARY KEY,
    nombre_usuario      VARCHAR(50)  NOT NULL UNIQUE,
    nombre_completo     VARCHAR(120) NOT NULL,
    correo              VARCHAR(120) NOT NULL UNIQUE,
    contrasena_hash     VARCHAR(255) NOT NULL,   -- se guarda el hash, nunca la contraseña en texto plano
    id_rol              INTEGER NOT NULL REFERENCES roles(id_rol),
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- parcelas

CREATE TABLE parcelas (
    id_parcela          SERIAL PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL,
    ubicacion           VARCHAR(150),
    area_hectareas      NUMERIC(10,2) CHECK (area_hectareas > 0),
    altitud_msnm        NUMERIC(6,2)  CHECK (altitud_msnm >= 0),
    id_usuario_registro INTEGER REFERENCES usuarios(id_usuario),
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- temporadas

CREATE TABLE temporadas (
    id_temporada    SERIAL PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL UNIQUE,   -- ej: '2025-2026'
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE,
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_temporada_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- tipos_cafe

CREATE TABLE tipos_cafe (
    id_tipo_cafe    SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL UNIQUE,   -- ej: 'Arábica Typica'
    descripcion     TEXT
);

-- almacenes

CREATE TABLE almacenes (
    id_almacen      SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE,
    ubicacion       VARCHAR(150),
    capacidad_kg    NUMERIC(10,2) CHECK (capacidad_kg > 0),
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

-- catalogo_tipos_movimiento
--     Normaliza los tipos de movimiento en vez de usar un CHECK fijo,
--     así se pueden agregar nuevos tipos sin alterar la estructura.

CREATE TABLE catalogo_tipos_movimiento (
    id_tipo_movimiento  SERIAL PRIMARY KEY,
    nombre              VARCHAR(20) NOT NULL UNIQUE
                         CHECK (nombre IN ('entrada','salida','traslado','merma')),
    descripcion         VARCHAR(150)
);

INSERT INTO catalogo_tipos_movimiento (nombre, descripcion) VALUES
('entrada',  'Ingreso de café al inventario (cosecha nueva o ajuste positivo)'),
('salida',   'Salida de café del inventario (venta o despacho)'),
('traslado', 'Movimiento de café entre dos almacenes'),
('merma',    'Pérdida de café por daño, humedad, plagas u otra causa');


-- 2. PRODUCCIÓN

-- lotes_cosecha

CREATE TABLE lotes_cosecha (
    id_lote                 SERIAL PRIMARY KEY,
    id_parcela              INTEGER NOT NULL REFERENCES parcelas(id_parcela),
    id_temporada            INTEGER NOT NULL REFERENCES temporadas(id_temporada),
    id_tipo_cafe            INTEGER NOT NULL REFERENCES tipos_cafe(id_tipo_cafe),
    fecha_cosecha           DATE NOT NULL,
    cantidad_recolectada_kg NUMERIC(10,2) NOT NULL CHECK (cantidad_recolectada_kg > 0),
    estado                  VARCHAR(20) NOT NULL DEFAULT 'pendiente_analisis'
                             CHECK (estado IN ('pendiente_analisis','clasificado')),
    id_usuario_registro     INTEGER REFERENCES usuarios(id_usuario),
    fecha_registro          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- datos_agronomicos  (uno por lote)

CREATE TABLE datos_agronomicos (
    id_dato         SERIAL PRIMARY KEY,
    id_lote         INTEGER NOT NULL UNIQUE REFERENCES lotes_cosecha(id_lote) ON DELETE CASCADE,
    clima           VARCHAR(80),
    plagas          VARCHAR(150),
    humedad         NUMERIC(5,2) CHECK (humedad BETWEEN 0 AND 100),
    rendimiento     NUMERIC(10,2) CHECK (rendimiento >= 0),
    fecha_registro  TIMESTAMP NOT NULL DEFAULT NOW()
);


-- 3. MOTOR DE INTELIGENCIA ARTIFICIAL

--     analisis_ejecuciones
--     Registra cada corrida del modelo K-Means (un "batch" de análisis),
--     útil para trazabilidad y para comparar resultados entre ejecuciones.

CREATE TABLE analisis_ejecuciones (
    id_ejecucion         SERIAL PRIMARY KEY,
    fecha_ejecucion      TIMESTAMP NOT NULL DEFAULT NOW(),
    k_utilizado          INTEGER NOT NULL CHECK (k_utilizado > 0),
    metodo_seleccion_k   VARCHAR(50) NOT NULL DEFAULT 'metodo_del_codo',
    cantidad_lotes_procesados INTEGER NOT NULL DEFAULT 0,
    observaciones        TEXT,
    id_usuario_ejecuto   INTEGER REFERENCES usuarios(id_usuario)
);

-- clasificaciones_ia  (una por lote)

CREATE TABLE clasificaciones_ia (
    id_clasificacion    SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL UNIQUE REFERENCES lotes_cosecha(id_lote) ON DELETE CASCADE,
    id_ejecucion        INTEGER NOT NULL REFERENCES analisis_ejecuciones(id_ejecucion),
    numero_cluster      INTEGER NOT NULL CHECK (numero_cluster >= 0),
    interpretacion      VARCHAR(50),   -- ej: 'Rendimiento alto' (se define tras analizar los clústeres)
    fecha_clasificacion TIMESTAMP NOT NULL DEFAULT NOW()
);


-- 4. INVENTARIO

-- inventario_existencias

CREATE TABLE inventario_existencias (
    id_existencia       SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL REFERENCES lotes_cosecha(id_lote),
    id_almacen          INTEGER NOT NULL REFERENCES almacenes(id_almacen),
    cantidad_disponible NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cantidad_disponible >= 0),
    stock_minimo        NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
    fecha_ingreso        DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_existencia_lote_almacen UNIQUE (id_lote, id_almacen)
);

-- movimientos_inventario

CREATE TABLE movimientos_inventario (
    id_movimiento       SERIAL PRIMARY KEY,
    id_lote             INTEGER NOT NULL REFERENCES lotes_cosecha(id_lote),
    id_almacen_origen   INTEGER REFERENCES almacenes(id_almacen),   -- NULL si es una entrada nueva
    id_almacen_destino  INTEGER REFERENCES almacenes(id_almacen),   -- NULL si es una salida/merma final
    id_tipo_movimiento  INTEGER NOT NULL REFERENCES catalogo_tipos_movimiento(id_tipo_movimiento),
    cantidad            NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
    id_usuario_registro INTEGER REFERENCES usuarios(id_usuario),
    observaciones       VARCHAR(200),
    fecha_movimiento    TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_movimiento_almacenes CHECK (
        id_almacen_origen IS NOT NULL OR id_almacen_destino IS NOT NULL
    )
);

-- alertas_inventario
--     Se llenan automáticamente mediante trigger (ver sección 7)
--     cuando una existencia baja al nivel de stock mínimo o menos.

CREATE TABLE alertas_inventario (
    id_alerta       SERIAL PRIMARY KEY,
    id_existencia   INTEGER NOT NULL REFERENCES inventario_existencias(id_existencia),
    fecha_generada  TIMESTAMP NOT NULL DEFAULT NOW(),
    atendida        BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_atendida  TIMESTAMP
);


-- 5. AUDITORÍA

-- bitacora_operaciones
--     Registro genérico de operaciones relevantes (sección 13 del
--     documento: "Registro de operaciones relevantes").
--     Se llena vía trigger genérico (ver sección 7).

CREATE TABLE bitacora_operaciones (
    id_bitacora      BIGSERIAL PRIMARY KEY,
    tabla_afectada   VARCHAR(50) NOT NULL,
    operacion        VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    id_usuario       INTEGER REFERENCES usuarios(id_usuario),
    fecha_operacion  TIMESTAMP NOT NULL DEFAULT NOW(),
    detalle          JSONB NOT NULL
);

-- 6. ÍNDICES

CREATE INDEX idx_usuarios_rol                ON usuarios(id_rol);
CREATE INDEX idx_parcelas_usuario             ON parcelas(id_usuario_registro);

CREATE INDEX idx_lotes_parcela                ON lotes_cosecha(id_parcela);
CREATE INDEX idx_lotes_temporada              ON lotes_cosecha(id_temporada);
CREATE INDEX idx_lotes_tipo_cafe              ON lotes_cosecha(id_tipo_cafe);
CREATE INDEX idx_lotes_estado                 ON lotes_cosecha(estado);

CREATE INDEX idx_clasificaciones_ejecucion    ON clasificaciones_ia(id_ejecucion);
CREATE INDEX idx_clasificaciones_cluster      ON clasificaciones_ia(numero_cluster);

CREATE INDEX idx_existencias_lote             ON inventario_existencias(id_lote);
CREATE INDEX idx_existencias_almacen          ON inventario_existencias(id_almacen);

CREATE INDEX idx_movimientos_lote             ON movimientos_inventario(id_lote);
CREATE INDEX idx_movimientos_tipo             ON movimientos_inventario(id_tipo_movimiento);
CREATE INDEX idx_movimientos_fecha            ON movimientos_inventario(fecha_movimiento);

CREATE INDEX idx_alertas_existencia           ON alertas_inventario(id_existencia);
CREATE INDEX idx_alertas_atendida             ON alertas_inventario(atendida) WHERE atendida = FALSE;

CREATE INDEX idx_bitacora_tabla               ON bitacora_operaciones(tabla_afectada);
CREATE INDEX idx_bitacora_fecha               ON bitacora_operaciones(fecha_operacion);


-- 7. FUNCIONES Y TRIGGERS

-- Actualizar automáticamente "updated_at" en cada UPDATE

CREATE OR REPLACE FUNCTION fn_actualizar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();

CREATE TRIGGER trg_parcelas_updated_at
    BEFORE UPDATE ON parcelas
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();

CREATE TRIGGER trg_lotes_updated_at
    BEFORE UPDATE ON lotes_cosecha
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();

CREATE TRIGGER trg_existencias_updated_at
    BEFORE UPDATE ON inventario_existencias
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_updated_at();


-- Marcar un lote como "clasificado" en cuanto se inserta
--     su resultado de K-Means.

CREATE OR REPLACE FUNCTION fn_marcar_lote_clasificado()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE lotes_cosecha
    SET estado = 'clasificado'
    WHERE id_lote = NEW.id_lote;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_marcar_lote_clasificado
    AFTER INSERT ON clasificaciones_ia
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_lote_clasificado();


-- Mantener inventario_existencias sincronizado cada vez que
--     se registra un movimiento (entrada, salida, traslado, merma).
--     Esto evita que el equipo tenga que actualizar existencias
--     "a mano" desde PHP; solo se inserta el movimiento.

CREATE OR REPLACE FUNCTION fn_procesar_movimiento_inventario()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo VARCHAR(20);
BEGIN
    SELECT nombre INTO v_tipo
    FROM catalogo_tipos_movimiento
    WHERE id_tipo_movimiento = NEW.id_tipo_movimiento;

    IF v_tipo = 'entrada' THEN
        INSERT INTO inventario_existencias (id_lote, id_almacen, cantidad_disponible, fecha_ingreso)
        VALUES (NEW.id_lote, NEW.id_almacen_destino, NEW.cantidad, CURRENT_DATE)
        ON CONFLICT (id_lote, id_almacen)
        DO UPDATE SET cantidad_disponible = inventario_existencias.cantidad_disponible + NEW.cantidad;

    ELSIF v_tipo IN ('salida', 'merma') THEN
        UPDATE inventario_existencias
        SET cantidad_disponible = cantidad_disponible - NEW.cantidad
        WHERE id_lote = NEW.id_lote AND id_almacen = NEW.id_almacen_origen;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No existe existencia registrada para el lote % en el almacén %',
                NEW.id_lote, NEW.id_almacen_origen;
        END IF;

    ELSIF v_tipo = 'traslado' THEN
        UPDATE inventario_existencias
        SET cantidad_disponible = cantidad_disponible - NEW.cantidad
        WHERE id_lote = NEW.id_lote AND id_almacen = NEW.id_almacen_origen;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No existe existencia registrada para el lote % en el almacén origen %',
                NEW.id_lote, NEW.id_almacen_origen;
        END IF;

        INSERT INTO inventario_existencias (id_lote, id_almacen, cantidad_disponible, fecha_ingreso)
        VALUES (NEW.id_lote, NEW.id_almacen_destino, NEW.cantidad, CURRENT_DATE)
        ON CONFLICT (id_lote, id_almacen)
        DO UPDATE SET cantidad_disponible = inventario_existencias.cantidad_disponible + NEW.cantidad;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_procesar_movimiento
    AFTER INSERT ON movimientos_inventario
    FOR EACH ROW EXECUTE FUNCTION fn_procesar_movimiento_inventario();


-- Generar alerta automática cuando la existencia baja
--     al nivel de stock mínimo o menos.

CREATE OR REPLACE FUNCTION fn_generar_alerta_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad_disponible <= NEW.stock_minimo THEN
        IF NOT EXISTS (
            SELECT 1 FROM alertas_inventario
            WHERE id_existencia = NEW.id_existencia AND atendida = FALSE
        ) THEN
            INSERT INTO alertas_inventario (id_existencia, fecha_generada, atendida)
            VALUES (NEW.id_existencia, NOW(), FALSE);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generar_alerta_stock
    AFTER INSERT OR UPDATE OF cantidad_disponible ON inventario_existencias
    FOR EACH ROW EXECUTE FUNCTION fn_generar_alerta_stock();


-- Auditoría genérica: registra cada INSERT/UPDATE/DELETE
--     en las tablas críticas del sistema.
--     Si la aplicación (PHP) hace, al inicio de cada transacción:
--         SET LOCAL app.usuario_actual = '<id_usuario>';
--     entonces la bitácora también queda asociada al usuario.
--     Si no se define esa variable, el campo id_usuario queda NULL.

CREATE OR REPLACE FUNCTION fn_registrar_bitacora()
RETURNS TRIGGER AS $$
DECLARE
    v_id_usuario INTEGER;
BEGIN
    BEGIN
        v_id_usuario := current_setting('app.usuario_actual', true)::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_id_usuario := NULL;
    END;

    IF TG_OP = 'DELETE' THEN
        INSERT INTO bitacora_operaciones (tabla_afectada, operacion, id_usuario, detalle)
        VALUES (TG_TABLE_NAME, TG_OP, v_id_usuario, to_jsonb(OLD));
        RETURN OLD;
    ELSE
        INSERT INTO bitacora_operaciones (tabla_afectada, operacion, id_usuario, detalle)
        VALUES (TG_TABLE_NAME, TG_OP, v_id_usuario, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bitacora_movimientos
    AFTER INSERT OR UPDATE OR DELETE ON movimientos_inventario
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora();

CREATE TRIGGER trg_bitacora_clasificaciones
    AFTER INSERT OR UPDATE OR DELETE ON clasificaciones_ia
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora();

CREATE TRIGGER trg_bitacora_existencias
    AFTER INSERT OR UPDATE OR DELETE ON inventario_existencias
    FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora();

-- Nota: pueden agregar este mismo trigger a otras tablas (por ejemplo
-- lotes_cosecha o usuarios) repitiendo el patrón de arriba, si
-- necesitan trazabilidad más amplia.

-- 8. VISTAS (soporte directo para el dashboard)

-- Lotes pendientes de análisis (para que PHP sepa qué enviar a FastAPI)

CREATE OR REPLACE VIEW vista_lotes_pendientes_analisis AS
SELECT
    l.id_lote,
    l.fecha_cosecha,
    l.cantidad_recolectada_kg,
    t.nombre         AS tipo_cafe,
    p.nombre         AS parcela,
    p.altitud_msnm,
    d.clima,
    d.plagas,
    d.humedad,
    d.rendimiento
FROM lotes_cosecha l
JOIN tipos_cafe t          ON t.id_tipo_cafe = l.id_tipo_cafe
JOIN parcelas p             ON p.id_parcela = l.id_parcela
LEFT JOIN datos_agronomicos d ON d.id_lote = l.id_lote
WHERE l.estado = 'pendiente_analisis';

-- Estado actual del inventario, con lote, tipo de café,
--     almacén y clasificación de IA

CREATE OR REPLACE VIEW vista_inventario_actual AS
SELECT
    e.id_existencia,
    l.id_lote,
    tc.nombre           AS tipo_cafe,
    a.nombre            AS almacen,
    e.cantidad_disponible,
    e.stock_minimo,
    (e.cantidad_disponible <= e.stock_minimo) AS stock_bajo,
    c.numero_cluster,
    c.interpretacion    AS clasificacion_ia,
    e.fecha_ingreso
FROM inventario_existencias e
JOIN lotes_cosecha l            ON l.id_lote = e.id_lote
JOIN tipos_cafe tc               ON tc.id_tipo_cafe = l.id_tipo_cafe
JOIN almacenes a                 ON a.id_almacen = e.id_almacen
LEFT JOIN clasificaciones_ia c  ON c.id_lote = l.id_lote;

-- Alertas de inventario activas (no atendidas)

CREATE OR REPLACE VIEW vista_alertas_activas AS
SELECT
    al.id_alerta,
    e.id_lote,
    a.nombre            AS almacen,
    e.cantidad_disponible,
    e.stock_minimo,
    al.fecha_generada
FROM alertas_inventario al
JOIN inventario_existencias e ON e.id_existencia = al.id_existencia
JOIN almacenes a               ON a.id_almacen = e.id_almacen
WHERE al.atendida = FALSE;

-- Distribución de lotes por clúster (indicador de rendimiento)

CREATE OR REPLACE VIEW vista_distribucion_clusters AS
SELECT
    numero_cluster,
    interpretacion,
    COUNT(*) AS cantidad_lotes
FROM clasificaciones_ia
GROUP BY numero_cluster, interpretacion
ORDER BY numero_cluster;


-- 9. COMENTARIOS DE DOCUMENTACIÓN

COMMENT ON TABLE roles                    IS 'Roles de usuario del sistema (administrador, operador, consulta, etc.)';
COMMENT ON TABLE usuarios                 IS 'Usuarios que operan el sistema, usados para trazabilidad de registros';
COMMENT ON TABLE parcelas                 IS 'Terrenos de producción de café';
COMMENT ON TABLE temporadas               IS 'Períodos de cosecha (ej. 2025-2026)';
COMMENT ON TABLE tipos_cafe               IS 'Variedades de café cultivadas';
COMMENT ON TABLE almacenes                IS 'Ubicaciones físicas donde se almacena el café';
COMMENT ON TABLE catalogo_tipos_movimiento IS 'Tipos válidos de movimiento de inventario';
COMMENT ON TABLE lotes_cosecha            IS 'Lotes de café cosechados, unidad central del sistema';
COMMENT ON TABLE datos_agronomicos        IS 'Variables agronómicas asociadas a cada lote (clima, plagas, humedad, rendimiento)';
COMMENT ON TABLE analisis_ejecuciones     IS 'Historial de corridas del modelo K-Means';
COMMENT ON TABLE clasificaciones_ia       IS 'Resultado de clasificación de cada lote según K-Means';
COMMENT ON TABLE inventario_existencias   IS 'Existencia actual de cada lote por almacén';
COMMENT ON TABLE movimientos_inventario   IS 'Historial de entradas, salidas, traslados y mermas (trazabilidad física)';
COMMENT ON TABLE alertas_inventario       IS 'Alertas generadas automáticamente cuando la existencia baja del stock mínimo';
COMMENT ON TABLE bitacora_operaciones     IS 'Auditoría genérica de operaciones sobre tablas críticas del sistema';


-- 10. APÉNDICE: Roles de acceso a nivel de base de datos (REFERENCIA)

-- Esto es independiente de la tabla "usuarios" (que es a nivel de
-- aplicación). Aquí se muestra cómo crear un usuario/rol de PostgreSQL
-- con privilegios limitados, para que el backend PHP NO se conecte
-- con un superusuario. Ajustar el nombre y la contraseña antes de usar.
--
-- CREATE ROLE agrocafe_app WITH LOGIN PASSWORD 'defina_una_contrasena_segura';
-- GRANT CONNECT ON DATABASE agrocafe TO agrocafe_app;
-- GRANT USAGE ON SCHEMA public TO agrocafe_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO agrocafe_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO agrocafe_app;
--
-- Recomendación: guardar la contraseña real solo en variables de entorno
-- del backend (sección 13 del documento: "Uso de variables de entorno
-- para configuraciones"), nunca en el repositorio de código.