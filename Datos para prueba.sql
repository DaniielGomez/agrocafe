-- 1. PARCELAS

INSERT INTO parcelas (nombre, ubicacion, area_hectareas, altitud_msnm) VALUES
('Parcela El Mirador', 'Jarabacoa, La Vega', 3.50, 850.00),
('Parcela Los Robles', 'Polo, Barahona', 5.20, 1200.00),
('Parcela La Esperanza', 'Constanza, La Vega', 2.80, 1450.00);

-- 2. TEMPORADAS

INSERT INTO temporadas (nombre, fecha_inicio, fecha_fin) VALUES
('2024-2025', '2024-10-01', '2025-03-31'),
('2025-2026', '2025-10-01', NULL);

-- 3. TIPOS_CAFE

INSERT INTO tipos_cafe (nombre, descripcion) VALUES
('Arábica Typica', 'Variedad tradicional de grano alargado, sabor suave'),
('Arábica Caturra', 'Variedad de porte bajo, buena productividad'),
('Robusta', 'Variedad resistente, mayor contenido de cafeína');

-- 4. LOTES_COSECHA
--    (12 lotes distribuidos entre parcelas, temporadas y tipos)

INSERT INTO lotes_cosecha (id_parcela, id_temporada, id_tipo_cafe, fecha_cosecha, cantidad_recolectada_kg) VALUES
(1, 1, 1, '2024-11-15', 320.50),
(1, 1, 2, '2024-11-20', 410.00),
(2, 1, 1, '2024-12-01', 275.30),
(2, 1, 3, '2024-12-05', 190.00),
(3, 1, 2, '2024-12-10', 505.75),
(3, 1, 1, '2024-12-18', 388.20),
(1, 2, 2, '2025-11-10', 350.00),
(1, 2, 1, '2025-11-14', 298.60),
(2, 2, 3, '2025-11-22', 210.40),
(2, 2, 1, '2025-11-28', 330.90),
(3, 2, 2, '2025-12-02', 470.10),
(3, 2, 1, '2025-12-08', 402.50);

-- 5. DATOS_AGRONOMICOS
--    (uno por lote, en el mismo orden de id_lote 1-12)

INSERT INTO datos_agronomicos (id_lote, clima, plagas, humedad, rendimiento) VALUES
(1,  'Templado húmedo', 'Broca leve',        62.50, 850.00),
(2,  'Templado húmedo', 'Ninguna',           58.00, 1120.00),
(3,  'Cálido',          'Roya moderada',     70.20, 650.00),
(4,  'Cálido',          'Broca alta',        75.00, 480.00),
(5,  'Frío',            'Ninguna',           55.10, 1340.00),
(6,  'Frío',            'Roya leve',         57.80, 980.00),
(7,  'Templado húmedo', 'Ninguna',           60.00, 1050.00),
(8,  'Templado húmedo', 'Broca leve',        63.40, 870.00),
(9,  'Cálido',          'Roya alta',         78.60, 420.00),
(10, 'Cálido',          'Broca moderada',    72.10, 700.00),
(11, 'Frío',            'Ninguna',           54.30, 1290.00),
(12, 'Frío',            'Roya leve',         56.90, 1010.00);

-- 6. CLASIFICACIONES_IA
--    Ejemplo de resultados YA procesados (para probar dashboard).
--    En un caso real, esto lo generaría la API de FastAPI.
--    Se dejan 4 lotes SIN clasificar (9, 10, 11, 12) para poder
--    probar el flujo de "lotes pendientes de análisis".

INSERT INTO clasificaciones_ia (id_lote, numero_cluster, interpretacion) VALUES
(1, 1, 'Rendimiento medio'),
(2, 2, 'Rendimiento alto'),
(3, 0, 'Rendimiento bajo'),
(4, 0, 'Rendimiento bajo'),
(5, 2, 'Rendimiento alto'),
(6, 1, 'Rendimiento medio'),
(7, 1, 'Rendimiento medio'),
(8, 1, 'Rendimiento medio');

-- 7. ALMACENES

INSERT INTO almacenes (nombre, ubicacion, capacidad_kg) VALUES
('Almacén Central Jarabacoa', 'Jarabacoa, La Vega', 5000.00),
('Almacén Norte Constanza', 'Constanza, La Vega', 3000.00);

-- 8. INVENTARIO_EXISTENCIAS
--    Solo para los lotes ya clasificados (1-8), asignados a un almacén

INSERT INTO inventario_existencias (id_lote, id_almacen, cantidad_disponible, stock_minimo, fecha_ingreso) VALUES
(1, 1, 320.50, 50.00, '2024-11-16'),
(2, 1, 400.00, 50.00, '2024-11-21'),   -- ya bajó un poco por una salida (ver movimientos)
(3, 2, 275.30, 40.00, '2024-12-02'),
(4, 2, 190.00, 40.00, '2024-12-06'),
(5, 1, 505.75, 60.00, '2024-12-11'),
(6, 1, 30.00,  40.00, '2024-12-19'),   -- por debajo del stock mínimo (para probar alertas)
(7, 2, 350.00, 50.00, '2025-11-11'),
(8, 2, 298.60, 50.00, '2025-11-15');

-- 9. MOVIMIENTOS_INVENTARIO
--    Algunos ejemplos: entrada inicial, salida, traslado y merma

INSERT INTO movimientos_inventario (id_lote, id_almacen_origen, id_almacen_destino, tipo_movimiento, cantidad, fecha_movimiento) VALUES
(1, NULL, 1, 'entrada', 320.50, '2024-11-16 09:00:00'),
(2, NULL, 1, 'entrada', 410.00, '2024-11-21 09:15:00'),
(2, 1,    NULL, 'salida', 10.00, '2024-12-15 14:30:00'),   -- venta o despacho
(3, NULL, 2, 'entrada', 275.30, '2024-12-02 10:00:00'),
(4, NULL, 2, 'entrada', 190.00, '2024-12-06 10:20:00'),
(5, NULL, 1, 'entrada', 505.75, '2024-12-11 08:45:00'),
(6, NULL, 1, 'entrada', 388.20, '2024-12-19 11:00:00'),
(6, 1,    NULL, 'merma', 358.20, '2025-01-10 16:00:00'),   -- gran pérdida, deja solo 30 kg
(6, 2,    1,    'traslado', 100.00, '2024-12-22 13:00:00'), -- ejemplo de traslado entre almacenes
(7, NULL, 2, 'entrada', 350.00, '2025-11-11 09:00:00'),
(8, NULL, 2, 'entrada', 298.60, '2025-11-15 09:30:00');