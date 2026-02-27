-- ============================================================================
-- DATA1500 - Oblig 1: Arbeidskrav I våren 2026
-- Initialiserings-skript for PostgreSQL
-- ============================================================================
-- Opprett grunnleggende tabeller
-- Sett inn testdata
-- DBA setninger (rolle: kunde, bruker: kunde_1)
-- Eventuelt: Opprett indekser for ytelse
-- Vis at initialisering er fullført (kan se i loggen fra "docker-compose log"
SELECT 'Database initialisert!' as status;
-- ============================================================================
BEGIN;

-- Kjørbar på nytt
DROP TABLE IF EXISTS app_user_map CASCADE;
DROP TABLE IF EXISTS utleie CASCADE;
DROP TABLE IF EXISTS sykkel CASCADE;
DROP TABLE IF EXISTS las CASCADE;
DROP TABLE IF EXISTS stasjon CASCADE;
DROP TABLE IF EXISTS kunde CASCADE;

-- =========================
-- TABELLER
-- =========================

CREATE TABLE kunde (
                       kunde_id        SERIAL PRIMARY KEY,
                       mobilnummer     VARCHAR(15) NOT NULL UNIQUE,
                       epost           TEXT NOT NULL UNIQUE,
                       fornavn         VARCHAR(60) NOT NULL,
                       etternavn       VARCHAR(60) NOT NULL,
                       registrert_tid  TIMESTAMPTZ NOT NULL DEFAULT now(),
                       CONSTRAINT chk_mobil_format CHECK (mobilnummer ~ '^[0-9]{8}$'),
CONSTRAINT chk_epost_format
  CHECK (epost LIKE '%@%.%')
);

CREATE TABLE stasjon (
                         stasjon_id  SERIAL PRIMARY KEY,
                         navn        VARCHAR(80) NOT NULL UNIQUE,
                         adresse     TEXT
);

CREATE TABLE las (
                     las_id      SERIAL PRIMARY KEY,
                     stasjon_id  INT NOT NULL REFERENCES stasjon(stasjon_id) ON DELETE CASCADE,
                     las_nr      INT NOT NULL,
                     CONSTRAINT uq_las_per_stasjon UNIQUE (stasjon_id, las_nr),
                     CONSTRAINT chk_las_nr CHECK (las_nr >= 1)
);

CREATE TABLE sykkel (
                        sykkel_id          BIGSERIAL PRIMARY KEY,
                        tatt_i_bruk_dato   DATE NOT NULL,
                        stasjon_id         INT NULL REFERENCES stasjon(stasjon_id),
                        las_id             INT NULL REFERENCES las(las_id),
                        CONSTRAINT chk_sykkel_plassering
                            CHECK (
                                (stasjon_id IS NULL AND las_id IS NULL)
                                    OR
                                (stasjon_id IS NOT NULL AND las_id IS NOT NULL)
                                )
);

CREATE TABLE utleie (
                        utleie_id              BIGSERIAL PRIMARY KEY,
                        kunde_id               INT NOT NULL REFERENCES kunde(kunde_id),
                        sykkel_id              BIGINT NOT NULL REFERENCES sykkel(sykkel_id),
                        utlevert_tid           TIMESTAMPTZ NOT NULL,
                        innlevert_tid          TIMESTAMPTZ NULL,
                        utlevert_stasjon_id    INT NOT NULL REFERENCES stasjon(stasjon_id),
                        innlevert_stasjon_id   INT NULL REFERENCES stasjon(stasjon_id),
                        belop_ore              INT NOT NULL,
                        CONSTRAINT chk_tid CHECK (innlevert_tid IS NULL OR innlevert_tid >= utlevert_tid),
                        CONSTRAINT chk_belop CHECK (belop_ore >= 0)
);

-- =========================
-- TESTDATA
-- =========================

-- 5 stasjoner
INSERT INTO stasjon (navn, adresse) VALUES
                                        ('Sentrum', 'Storgata 1'),
                                        ('Øst', 'Østre vei 10'),
                                        ('Vest', 'Vestre allé 5'),
                                        ('Nord', 'Nordgata 7'),
                                        ('Sør', 'Sørveien 2');

-- 100 låser: 20 per stasjon
INSERT INTO las (stasjon_id, las_nr)
SELECT s.stasjon_id, gs.las_nr
FROM stasjon s
         CROSS JOIN generate_series(1, 20) AS gs(las_nr);

-- 5 kunder
INSERT INTO kunde (mobilnummer, epost, fornavn, etternavn) VALUES
                                                               ('90000001', 'ola.nordmann@example.com', 'Ola', 'Nordmann'),
                                                               ('90000002', 'kari.nordmann@example.com', 'Kari', 'Nordmann'),
                                                               ('90000003', 'ali.hassan@example.com', 'Ali', 'Hassan'),
                                                               ('90000004', 'sara.berg@example.com', 'Sara', 'Berg'),
                                                               ('90000005', 'per.hansen@example.com', 'Per', 'Hansen');

-- 100 sykler: parkeres i lås_id 1..100 (og stasjon_id hentes fra lås)
INSERT INTO sykkel (tatt_i_bruk_dato, stasjon_id, las_id)
SELECT
    (DATE '2023-01-01' + ((gs.id - 1) % 600))::date AS tatt_i_bruk_dato,
  l.stasjon_id,
  l.las_id
FROM generate_series(1, 100) AS gs(id)
    JOIN las l ON l.las_id = gs.id;

-- 45 avsluttede utleier
INSERT INTO utleie (
    kunde_id, sykkel_id, utlevert_tid, innlevert_tid,
    utlevert_stasjon_id, innlevert_stasjon_id, belop_ore
)
SELECT
    ((gs.id - 1) % 5) + 1 AS kunde_id,
    gs.id AS sykkel_id,
    now() - (gs.id || ' hours')::interval AS utlevert_tid,
    now() - ((gs.id - 1) || ' hours')::interval AS innlevert_tid,
    ((gs.id - 1) % 5) + 1 AS utlevert_stasjon_id,
    ((gs.id) % 5) + 1 AS innlevert_stasjon_id,
    4900 + (gs.id * 10) AS belop_ore
FROM generate_series(1, 45) AS gs(id);

-- 5 aktive utleier (innlevert_tid = NULL)
INSERT INTO utleie (
    kunde_id, sykkel_id, utlevert_tid, innlevert_tid,
    utlevert_stasjon_id, innlevert_stasjon_id, belop_ore
)
SELECT
    ((gs.id - 1) % 5) + 1 AS kunde_id,
    (45 + gs.id) AS sykkel_id,
    now() - ((24 + gs.id) || ' hours')::interval AS utlevert_tid,
    NULL,
    ((gs.id - 1) % 5) + 1 AS utlevert_stasjon_id,
    NULL,
    0
FROM generate_series(1, 5) AS gs(id);

-- Sykkel som er aktivt utleid har NULL stasjon og lås (hintet i oppgaven)
UPDATE sykkel s
SET stasjon_id = NULL,
    las_id = NULL
WHERE s.sykkel_id IN (
    SELECT u.sykkel_id FROM utleie u WHERE u.innlevert_tid IS NULL
);

-- =========================
-- DEL 3: TILGANGSKONTROLL (valgfritt å ha her, men funker)
-- =========================

-- Rolle + bruker
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kunde') THEN
CREATE ROLE kunde NOINHERIT;
END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kunde_1') THEN
    CREATE USER kunde_1 WITH PASSWORD 'kunde_1_pass';
END IF;
END$$;

GRANT kunde TO kunde_1;

GRANT USAGE ON SCHEMA public TO kunde;
GRANT SELECT ON kunde, stasjon, las, sykkel TO kunde;

-- Mapping fra DB-bruker til kunde_id
CREATE TABLE app_user_map (
                              db_username TEXT PRIMARY KEY,
                              kunde_id    INT NOT NULL REFERENCES kunde(kunde_id) ON DELETE CASCADE
);

INSERT INTO app_user_map (db_username, kunde_id)
VALUES ('kunde_1', 1)
    ON CONFLICT (db_username) DO UPDATE SET kunde_id = EXCLUDED.kunde_id;

CREATE OR REPLACE VIEW v_mine_utleier AS
SELECT u.*
FROM utleie u
         JOIN app_user_map a ON a.kunde_id = u.kunde_id
WHERE a.db_username = current_user;

GRANT SELECT ON v_mine_utleier TO kunde;

COMMIT;

-- Oppgave 2.2 (kjør manuelt i psql etterpå):
-- SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;