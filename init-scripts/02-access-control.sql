BEGIN;

-- 3.1 Roller og brukere
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

-- Gi rolle tilgang til schema + lesetilgang
GRANT USAGE ON SCHEMA public TO kunde;
GRANT SELECT ON kunde, stasjon, las, sykkel, utleie, app_user_map TO kunde;

-- 3.2 Begrenset visning for kunder (VIEW)
CREATE OR REPLACE VIEW v_mine_utleier AS
SELECT u.*
FROM utleie u
         JOIN app_user_map a ON a.kunde_id = u.kunde_id
WHERE a.db_username = current_user;

GRANT SELECT ON v_mine_utleier TO kunde;

COMMIT;