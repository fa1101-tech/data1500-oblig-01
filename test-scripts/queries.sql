-- ============================================================================
-- TEST-SKRIPT FOR OBLIG 1
-- ============================================================================

-- Kjør med: docker-compose exec postgres psql -h -U admin -d data1500_db -f test-scripts/queries.sql

-- En test med en SQL-spørring mot metadata i PostgreSQL (kan slettes fra din script)
select nspname as schema_name from pg_catalog.pg_namespace;
-- Oppgave 5.1: Vis alle sykler
SELECT *
FROM sykkel;

-- Oppgave 5.2: Kunder sortert på etternavn
SELECT etternavn, fornavn, mobilnummer
FROM kunde
ORDER BY etternavn;

-- Oppgave 5.3: Sykler tatt i bruk etter 1. februar 2026
SELECT *
FROM sykkel
WHERE tatt_i_bruk_dato > DATE '2023-02-01';
-- Oppgave 5.4: Antall kunder
SELECT COUNT(*) AS antall_kunder
FROM kunde;

-- Oppgave 5.5: Antall utleier per kunde (inkl 0)
SELECT
    k.kunde_id,
    k.fornavn,
    k.etternavn,
    COUNT(u.utleie_id) AS antall_utleier
FROM kunde k
         LEFT JOIN utleie u ON u.kunde_id = k.kunde_id
GROUP BY k.kunde_id, k.fornavn, k.etternavn;

-- Oppgave 5.6: Kunder som aldri har leid sykkel
SELECT
    k.kunde_id,
    k.fornavn,
    k.etternavn
FROM kunde k
         LEFT JOIN utleie u ON u.kunde_id = k.kunde_id
WHERE u.utleie_id IS NULL;

-- Oppgave 5.7: Sykler som aldri har vært utleid
SELECT
    s.sykkel_id
FROM sykkel s
         LEFT JOIN utleie u ON u.sykkel_id = s.sykkel_id
WHERE u.utleie_id IS NULL;

-- Oppgave 5.8: Sykler som ikke er levert etter 1 døgn
SELECT
    u.utleie_id,
    u.sykkel_id,
    k.fornavn,
    k.etternavn,
    u.utlevert_tid
FROM utleie u
         JOIN kunde k ON k.kunde_id = u.kunde_id
WHERE u.innlevert_tid IS NULL
  AND u.utlevert_tid < now() - INTERVAL '24 hours';