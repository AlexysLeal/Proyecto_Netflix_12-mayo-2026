-- ============================================================
--  PROYECTO: Netflix
--  ARCHIVO:  bdnetflix.sql
--  MOTOR:    PostgreSQL 15+
--  AUTOR:    DBA Netflix Project
--  FECHA:    2026-05-13
--  DESC:     Creación completa del esquema relacional con
--            tablas, restricciones, índices y datos semilla.
-- ============================================================

-- ------------------------------------------------------------
-- 0. CONFIGURACIÓN INICIAL
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- 1. ELIMINAR TABLAS SI EXISTEN (orden inverso por FKs)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS calificacion       CASCADE;
DROP TABLE IF EXISTS lista_favoritos    CASCADE;
DROP TABLE IF EXISTS visualizacion      CASCADE;
DROP TABLE IF EXISTS contenido_genero   CASCADE;
DROP TABLE IF EXISTS episodio           CASCADE;
DROP TABLE IF EXISTS temporada          CASCADE;
DROP TABLE IF EXISTS genero             CASCADE;
DROP TABLE IF EXISTS contenido          CASCADE;
DROP TABLE IF EXISTS suscripcion        CASCADE;
DROP TABLE IF EXISTS plan               CASCADE;
DROP TABLE IF EXISTS dispositivo        CASCADE;
DROP TABLE IF EXISTS perfil             CASCADE;
DROP TABLE IF EXISTS usuario            CASCADE;

-- ============================================================
-- 2. TABLAS
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 USUARIO
-- ------------------------------------------------------------
CREATE TABLE usuario (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre           VARCHAR(100)  NOT NULL,
    email            VARCHAR(255)  NOT NULL UNIQUE,
    contrasena_hash  VARCHAR(255)  NOT NULL,
    pais             CHAR(2)       NOT NULL,
    fecha_registro   TIMESTAMP     NOT NULL DEFAULT NOW(),
    activo           BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_email CHECK (email LIKE '%@%')
);

COMMENT ON TABLE  usuario                IS 'Cuenta principal de acceso a la plataforma';
COMMENT ON COLUMN usuario.pais           IS 'Código ISO 3166-1 alpha-2 (MX, US, ES…)';
COMMENT ON COLUMN usuario.contrasena_hash IS 'Hash bcrypt de la contraseña';

-- ------------------------------------------------------------
-- 2.2 PERFIL
-- ------------------------------------------------------------
CREATE TABLE perfil (
    id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID         NOT NULL,
    nombre          VARCHAR(50)  NOT NULL,
    avatar_url      VARCHAR(500),
    es_infantil     BOOLEAN      NOT NULL DEFAULT FALSE,
    idioma          CHAR(5)      NOT NULL DEFAULT 'es',
    fecha_creacion  TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_perfil_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE
);

COMMENT ON TABLE  perfil            IS 'Sub-cuenta por persona (máx. 5 por usuario)';
COMMENT ON COLUMN perfil.idioma     IS 'Código BCP-47 (es, en, pt-BR…)';
COMMENT ON COLUMN perfil.es_infantil IS 'Activa filtro de contenido para menores';

-- ------------------------------------------------------------
-- 2.3 DISPOSITIVO
-- ------------------------------------------------------------
CREATE TABLE dispositivo (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID          NOT NULL,
    tipo            VARCHAR(30)   NOT NULL,
    nombre          VARCHAR(100),
    token_sesion    VARCHAR(500),
    ultimo_acceso   TIMESTAMP,

    CONSTRAINT fk_dispositivo_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE,
    CONSTRAINT chk_tipo_dispositivo
        CHECK (tipo IN ('smarttv', 'movil', 'tablet', 'pc', 'consola', 'otro'))
);

COMMENT ON TABLE  dispositivo              IS 'Equipos registrados por usuario';
COMMENT ON COLUMN dispositivo.token_sesion IS 'JWT activo de la sesión';

-- ------------------------------------------------------------
-- 2.4 PLAN
-- ------------------------------------------------------------
CREATE TABLE plan (
    id                      UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre                  VARCHAR(50)   NOT NULL UNIQUE,
    precio_mensual          DECIMAL(8,2)  NOT NULL,
    pantallas_simultaneas   SMALLINT      NOT NULL,
    calidad_video           VARCHAR(10)   NOT NULL,
    descargas               BOOLEAN       NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_precio         CHECK (precio_mensual >= 0),
    CONSTRAINT chk_pantallas      CHECK (pantallas_simultaneas BETWEEN 1 AND 4),
    CONSTRAINT chk_calidad_video  CHECK (calidad_video IN ('SD', 'HD', 'Full HD', '4K UHD'))
);

COMMENT ON TABLE plan IS 'Tiers de suscripción disponibles (Básico, Estándar, Premium)';

-- ------------------------------------------------------------
-- 2.5 SUSCRIPCION
-- ------------------------------------------------------------
CREATE TABLE suscripcion (
    id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id    UUID         NOT NULL,
    plan_id       UUID         NOT NULL,
    fecha_inicio  DATE         NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin     DATE,
    estado        VARCHAR(20)  NOT NULL DEFAULT 'activa',
    metodo_pago   VARCHAR(30)  NOT NULL,

    CONSTRAINT fk_suscripcion_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuario (id) ON DELETE CASCADE,
    CONSTRAINT fk_suscripcion_plan
        FOREIGN KEY (plan_id) REFERENCES plan (id),
    CONSTRAINT chk_estado
        CHECK (estado IN ('activa', 'pausada', 'cancelada', 'vencida')),
    CONSTRAINT chk_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio)
);

COMMENT ON TABLE  suscripcion           IS 'Contrato activo entre usuario y plan';
COMMENT ON COLUMN suscripcion.fecha_fin IS 'NULL indica suscripción indefinidamente activa';

-- ------------------------------------------------------------
-- 2.6 CONTENIDO
-- ------------------------------------------------------------
CREATE TABLE contenido (
    id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo         VARCHAR(200)  NOT NULL,
    tipo           VARCHAR(15)   NOT NULL,
    anio           SMALLINT      NOT NULL,
    clasificacion  VARCHAR(10)   NOT NULL,
    calificacion   NUMERIC(3,1)  DEFAULT 0.0,
    sinopsis       TEXT,
    pais_origen    CHAR(2)       NOT NULL,
    portada_url    VARCHAR(500),

    CONSTRAINT chk_tipo_contenido
        CHECK (tipo IN ('pelicula', 'serie', 'documental', 'miniserie')),
    CONSTRAINT chk_clasificacion
        CHECK (clasificacion IN ('G', 'PG', 'PG-13', 'R', 'NC-17', 'TV-Y', 'TV-G', 'TV-PG', 'TV-14', 'TV-MA')),
    CONSTRAINT chk_calificacion
        CHECK (calificacion BETWEEN 0.0 AND 10.0),
    CONSTRAINT chk_anio
        CHECK (anio BETWEEN 1888 AND EXTRACT(YEAR FROM NOW()) + 2)
);

COMMENT ON TABLE  contenido              IS 'Película, serie o documental del catálogo';
COMMENT ON COLUMN contenido.calificacion IS 'Promedio calculado desde la tabla calificacion';

-- ------------------------------------------------------------
-- 2.7 GENERO
-- ------------------------------------------------------------
CREATE TABLE genero (
    id      UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre  VARCHAR(60)  NOT NULL UNIQUE
);

COMMENT ON TABLE genero IS 'Clasificación temática del contenido';

-- ------------------------------------------------------------
-- 2.8 CONTENIDO_GENERO  (tabla pivote N:M)
-- ------------------------------------------------------------
CREATE TABLE contenido_genero (
    contenido_id  UUID  NOT NULL,
    genero_id     UUID  NOT NULL,

    PRIMARY KEY (contenido_id, genero_id),

    CONSTRAINT fk_cg_contenido
        FOREIGN KEY (contenido_id) REFERENCES contenido (id) ON DELETE CASCADE,
    CONSTRAINT fk_cg_genero
        FOREIGN KEY (genero_id) REFERENCES genero (id) ON DELETE CASCADE
);

COMMENT ON TABLE contenido_genero IS 'Relación N:M entre contenido y géneros';

-- ------------------------------------------------------------
-- 2.9 TEMPORADA
-- ------------------------------------------------------------
CREATE TABLE temporada (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    contenido_id  UUID          NOT NULL,
    numero        SMALLINT      NOT NULL,
    anio          SMALLINT,
    titulo        VARCHAR(150),

    CONSTRAINT fk_temporada_contenido
        FOREIGN KEY (contenido_id) REFERENCES contenido (id) ON DELETE CASCADE,
    CONSTRAINT chk_numero_temporada
        CHECK (numero >= 1),
    CONSTRAINT uq_temporada UNIQUE (contenido_id, numero)
);

COMMENT ON TABLE temporada IS 'Temporada perteneciente a una serie o miniserie';

-- ------------------------------------------------------------
-- 2.10 EPISODIO
-- ------------------------------------------------------------
CREATE TABLE episodio (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    contenido_id  UUID          NOT NULL,
    temporada_id  UUID,
    numero        SMALLINT      NOT NULL,
    titulo        VARCHAR(200)  NOT NULL,
    duracion_seg  INTEGER       NOT NULL,
    url_video     VARCHAR(500)  NOT NULL,

    CONSTRAINT fk_episodio_contenido
        FOREIGN KEY (contenido_id) REFERENCES contenido (id) ON DELETE CASCADE,
    CONSTRAINT fk_episodio_temporada
        FOREIGN KEY (temporada_id) REFERENCES temporada (id) ON DELETE SET NULL,
    CONSTRAINT chk_duracion
        CHECK (duracion_seg > 0),
    CONSTRAINT chk_numero_episodio
        CHECK (numero >= 1)
);

COMMENT ON TABLE  episodio              IS 'Unidad mínima de reproducción (incluye películas como episodio único)';
COMMENT ON COLUMN episodio.temporada_id IS 'NULL cuando el contenido es una película';

-- ------------------------------------------------------------
-- 2.11 VISUALIZACION
-- ------------------------------------------------------------
CREATE TABLE visualizacion (
    id            UUID       PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id     UUID       NOT NULL,
    episodio_id   UUID       NOT NULL,
    progreso_seg  INTEGER    NOT NULL DEFAULT 0,
    completado    BOOLEAN    NOT NULL DEFAULT FALSE,
    fecha_hora    TIMESTAMP  NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_viz_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfil (id) ON DELETE CASCADE,
    CONSTRAINT fk_viz_episodio
        FOREIGN KEY (episodio_id) REFERENCES episodio (id) ON DELETE CASCADE,
    CONSTRAINT chk_progreso
        CHECK (progreso_seg >= 0)
);

COMMENT ON TABLE  visualizacion             IS 'Historial de reproducción y progreso por perfil';
COMMENT ON COLUMN visualizacion.progreso_seg IS 'Segundo exacto donde se pausó la reproducción';
COMMENT ON COLUMN visualizacion.completado   IS 'TRUE cuando el perfil superó el 90% de la duración';

-- ------------------------------------------------------------
-- 2.12 LISTA_FAVORITOS
-- ------------------------------------------------------------
CREATE TABLE lista_favoritos (
    id              UUID       PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id       UUID       NOT NULL,
    contenido_id    UUID       NOT NULL,
    fecha_agregado  TIMESTAMP  NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_fav_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfil (id) ON DELETE CASCADE,
    CONSTRAINT fk_fav_contenido
        FOREIGN KEY (contenido_id) REFERENCES contenido (id) ON DELETE CASCADE,
    CONSTRAINT uq_favorito UNIQUE (perfil_id, contenido_id)
);

COMMENT ON TABLE lista_favoritos IS '"Mi lista" personal de cada perfil';

-- ------------------------------------------------------------
-- 2.13 CALIFICACION
-- ------------------------------------------------------------
CREATE TABLE calificacion (
    id            UUID       PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id     UUID       NOT NULL,
    contenido_id  UUID       NOT NULL,
    valor         SMALLINT   NOT NULL,
    fecha         TIMESTAMP  NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_cal_perfil
        FOREIGN KEY (perfil_id) REFERENCES perfil (id) ON DELETE CASCADE,
    CONSTRAINT fk_cal_contenido
        FOREIGN KEY (contenido_id) REFERENCES contenido (id) ON DELETE CASCADE,
    CONSTRAINT chk_valor
        CHECK (valor BETWEEN 1 AND 5),
    CONSTRAINT uq_calificacion UNIQUE (perfil_id, contenido_id)
);

COMMENT ON TABLE  calificacion       IS 'Valoración de 1 a 5 estrellas por perfil y contenido';
COMMENT ON COLUMN calificacion.valor IS '1 = pésimo … 5 = excelente';

-- ============================================================
-- 3. ÍNDICES DE RENDIMIENTO
-- ============================================================

-- Acceso frecuente por usuario
CREATE INDEX idx_perfil_usuario       ON perfil       (usuario_id);
CREATE INDEX idx_dispositivo_usuario  ON dispositivo  (usuario_id);
CREATE INDEX idx_suscripcion_usuario  ON suscripcion  (usuario_id);

-- Consultas de catálogo
CREATE INDEX idx_contenido_tipo       ON contenido    (tipo);
CREATE INDEX idx_contenido_anio       ON contenido    (anio);
CREATE INDEX idx_episodio_contenido   ON episodio     (contenido_id);
CREATE INDEX idx_episodio_temporada   ON episodio     (temporada_id);
CREATE INDEX idx_temporada_contenido  ON temporada    (contenido_id);

-- Historial y engagement
CREATE INDEX idx_viz_perfil           ON visualizacion  (perfil_id);
CREATE INDEX idx_viz_episodio         ON visualizacion  (episodio_id);
CREATE INDEX idx_viz_fecha            ON visualizacion  (fecha_hora DESC);
CREATE INDEX idx_fav_perfil           ON lista_favoritos(perfil_id);
CREATE INDEX idx_cal_contenido        ON calificacion   (contenido_id);

-- ============================================================
-- 4. DATOS SEMILLA (INSERT de ejemplo)
-- ============================================================

-- 4.1 Planes
INSERT INTO plan (id, nombre, precio_mensual, pantallas_simultaneas, calidad_video, descargas) VALUES
    ('a1000000-0000-0000-0000-000000000001', 'Básico',   99.00,  1, 'SD',      FALSE),
    ('a1000000-0000-0000-0000-000000000002', 'Estándar', 149.00, 2, 'Full HD', FALSE),
    ('a1000000-0000-0000-0000-000000000003', 'Premium',  219.00, 4, '4K UHD',  TRUE);

-- 4.2 Géneros
INSERT INTO genero (id, nombre) VALUES
    ('b1000000-0000-0000-0000-000000000001', 'Acción'),
    ('b1000000-0000-0000-0000-000000000002', 'Drama'),
    ('b1000000-0000-0000-0000-000000000003', 'Comedia'),
    ('b1000000-0000-0000-0000-000000000004', 'Terror'),
    ('b1000000-0000-0000-0000-000000000005', 'Ciencia Ficción'),
    ('b1000000-0000-0000-0000-000000000006', 'Documental'),
    ('b1000000-0000-0000-0000-000000000007', 'Thriller'),
    ('b1000000-0000-0000-0000-000000000008', 'Animación'),
    ('b1000000-0000-0000-0000-000000000009', 'Romance'),
    ('b1000000-0000-0000-0000-000000000010', 'Crimen');

-- 4.3 Usuarios
INSERT INTO usuario (id, nombre, email, contrasena_hash, pais) VALUES
    ('c1000000-0000-0000-0000-000000000001', 'Ana García',     'ana.garcia@email.com',   '$2b$12$abc123hash1', 'MX'),
    ('c1000000-0000-0000-0000-000000000002', 'Carlos López',   'carlos.lopez@email.com', '$2b$12$abc123hash2', 'MX'),
    ('c1000000-0000-0000-0000-000000000003', 'María Martínez', 'maria.m@email.com',      '$2b$12$abc123hash3', 'ES');

-- 4.4 Perfiles
INSERT INTO perfil (id, usuario_id, nombre, es_infantil, idioma) VALUES
    ('d1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Ana',     FALSE, 'es'),
    ('d1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Niños',   TRUE,  'es'),
    ('d1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 'Carlos',  FALSE, 'es'),
    ('d1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000003', 'María',   FALSE, 'es');

-- 4.5 Dispositivos
INSERT INTO dispositivo (id, usuario_id, tipo, nombre) VALUES
    ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'smarttv', 'Samsung Living Room'),
    ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'movil',   'iPhone de Ana'),
    ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 'pc',      'Laptop Carlos');

-- 4.6 Suscripciones
INSERT INTO suscripcion (id, usuario_id, plan_id, fecha_inicio, estado, metodo_pago) VALUES
    ('f1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', '2026-01-01', 'activa', 'tarjeta'),
    ('f1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', '2026-02-15', 'activa', 'paypal'),
    ('f1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001', '2025-11-01', 'activa', 'tarjeta');

-- 4.7 Contenido
INSERT INTO contenido (id, titulo, tipo, anio, clasificacion, calificacion, pais_origen) VALUES
    ('g1000000-0000-0000-0000-000000000001', 'Stranger Things',   'serie',       2016, 'TV-14', 8.7, 'US'),
    ('g1000000-0000-0000-0000-000000000002', 'El Juego del Calamar', 'serie',    2021, 'TV-MA', 8.0, 'KR'),
    ('g1000000-0000-0000-0000-000000000003', 'Inception',         'pelicula',    2010, 'PG-13', 8.8, 'US'),
    ('g1000000-0000-0000-0000-000000000004', 'Roma',              'pelicula',    2018, 'R',     7.7, 'MX'),
    ('g1000000-0000-0000-0000-000000000005', 'Our Planet',        'documental',  2019, 'G',     9.3, 'GB');

-- 4.8 Contenido-Género
INSERT INTO contenido_genero (contenido_id, genero_id) VALUES
    ('g1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000005'),  -- ST / Sci-Fi
    ('g1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000004'),  -- ST / Terror
    ('g1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000007'),  -- Calamar / Thriller
    ('g1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001'),  -- Calamar / Acción
    ('g1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000005'),  -- Inception / Sci-Fi
    ('g1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000007'),  -- Inception / Thriller
    ('g1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000002'),  -- Roma / Drama
    ('g1000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000006');  -- Our Planet / Documental

-- 4.9 Temporadas
INSERT INTO temporada (id, contenido_id, numero, anio) VALUES
    ('h1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000001', 1, 2016),
    ('h1000000-0000-0000-0000-000000000002', 'g1000000-0000-0000-0000-000000000001', 2, 2017),
    ('h1000000-0000-0000-0000-000000000003', 'g1000000-0000-0000-0000-000000000002', 1, 2021);

-- 4.10 Episodios
INSERT INTO episodio (id, contenido_id, temporada_id, numero, titulo, duracion_seg, url_video) VALUES
    -- Stranger Things T1
    ('i1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000001', 'h1000000-0000-0000-0000-000000000001', 1, 'El Mundo del Revés',           2940, 'https://cdn.netflix.com/st/s1e1.mp4'),
    ('i1000000-0000-0000-0000-000000000002', 'g1000000-0000-0000-0000-000000000001', 'h1000000-0000-0000-0000-000000000001', 2, 'La Chica en el Árbol de Arce', 2820, 'https://cdn.netflix.com/st/s1e2.mp4'),
    -- Calamar T1
    ('i1000000-0000-0000-0000-000000000003', 'g1000000-0000-0000-0000-000000000002', 'h1000000-0000-0000-0000-000000000003', 1, 'Un mundo diferente',           3300, 'https://cdn.netflix.com/squid/s1e1.mp4'),
    -- Inception (película = episodio único)
    ('i1000000-0000-0000-0000-000000000004', 'g1000000-0000-0000-0000-000000000003', NULL, 1, 'Inception',                    8880, 'https://cdn.netflix.com/inception.mp4'),
    -- Roma (película)
    ('i1000000-0000-0000-0000-000000000005', 'g1000000-0000-0000-0000-000000000004', NULL, 1, 'Roma',                         8160, 'https://cdn.netflix.com/roma.mp4');

-- 4.11 Visualizaciones
INSERT INTO visualizacion (perfil_id, episodio_id, progreso_seg, completado) VALUES
    ('d1000000-0000-0000-0000-000000000001', 'i1000000-0000-0000-0000-000000000001', 2940, TRUE),
    ('d1000000-0000-0000-0000-000000000001', 'i1000000-0000-0000-0000-000000000002', 1400, FALSE),
    ('d1000000-0000-0000-0000-000000000003', 'i1000000-0000-0000-0000-000000000004', 8880, TRUE),
    ('d1000000-0000-0000-0000-000000000004', 'i1000000-0000-0000-0000-000000000005', 5000, FALSE);

-- 4.12 Lista de favoritos
INSERT INTO lista_favoritos (perfil_id, contenido_id) VALUES
    ('d1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000001'),
    ('d1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000003'),
    ('d1000000-0000-0000-0000-000000000003', 'g1000000-0000-0000-0000-000000000002');

-- 4.13 Calificaciones
INSERT INTO calificacion (perfil_id, contenido_id, valor) VALUES
    ('d1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000001', 5),
    ('d1000000-0000-0000-0000-000000000001', 'g1000000-0000-0000-0000-000000000003', 5),
    ('d1000000-0000-0000-0000-000000000003', 'g1000000-0000-0000-0000-000000000002', 4),
    ('d1000000-0000-0000-0000-000000000004', 'g1000000-0000-0000-0000-000000000004', 5);

-- ============================================================
-- 5. VISTAS ÚTILES
-- ============================================================

-- Historial completo por perfil
CREATE OR REPLACE VIEW vw_historial_perfil AS
SELECT
    u.nombre        AS usuario,
    p.nombre        AS perfil,
    c.titulo        AS contenido,
    t.numero        AS temporada,
    e.numero        AS episodio,
    e.titulo        AS titulo_episodio,
    v.progreso_seg,
    e.duracion_seg,
    ROUND((v.progreso_seg::NUMERIC / e.duracion_seg) * 100, 1) AS porcentaje_visto,
    v.completado,
    v.fecha_hora
FROM visualizacion v
JOIN perfil    p ON p.id = v.perfil_id
JOIN usuario   u ON u.id = p.usuario_id
JOIN episodio  e ON e.id = v.episodio_id
JOIN contenido c ON c.id = e.contenido_id
LEFT JOIN temporada t ON t.id = e.temporada_id
ORDER BY v.fecha_hora DESC;

-- Contenido más popular (por visualizaciones completadas)
CREATE OR REPLACE VIEW vw_contenido_popular AS
SELECT
    c.titulo,
    c.tipo,
    COUNT(v.id)                    AS total_reproducciones,
    SUM(v.completado::INT)         AS visualizaciones_completas,
    ROUND(AVG(cal.valor), 2)       AS calificacion_promedio
FROM contenido c
LEFT JOIN episodio    e   ON e.contenido_id = c.id
LEFT JOIN visualizacion v ON v.episodio_id  = e.id
LEFT JOIN calificacion cal ON cal.contenido_id = c.id
GROUP BY c.id, c.titulo, c.tipo
ORDER BY total_reproducciones DESC;

-- Suscripciones activas con detalle de plan
CREATE OR REPLACE VIEW vw_suscripciones_activas AS
SELECT
    u.nombre        AS usuario,
    u.email,
    u.pais,
    pl.nombre       AS plan,
    pl.precio_mensual,
    pl.calidad_video,
    s.fecha_inicio,
    s.metodo_pago
FROM suscripcion s
JOIN usuario u ON u.id = s.usuario_id
JOIN plan    pl ON pl.id = s.plan_id
WHERE s.estado = 'activa';

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
