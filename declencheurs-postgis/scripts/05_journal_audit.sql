-- =====================================================================
--  GEO7531 - Déclencheurs 05 : Un journal des modifications (audit)
--  Section 7 du tutoriel
--
--  Qui a modifié quoi, quand, et quelle était la valeur avant ?
--  Une seule fonction, réutilisable sur n'importe quelle table.
-- =====================================================================

DROP TABLE IF EXISTS labo.journal;
CREATE TABLE labo.journal (
  id          bigserial PRIMARY KEY,
  quand       timestamptz NOT NULL DEFAULT now(),
  qui         text        NOT NULL DEFAULT current_user,
  table_nom   text        NOT NULL,
  operation   text        NOT NULL,      -- INSERT, UPDATE ou DELETE
  avant       jsonb,                     -- attributs avant (UPDATE, DELETE)
  apres       jsonb,                     -- attributs après (INSERT, UPDATE)
  geom_avant  geometry,
  geom_apres  geometry
);


CREATE OR REPLACE FUNCTION labo.f_journaliser()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_avant jsonb;
  v_apres jsonb;
BEGIN
  -- OLD n'existe pas pour un INSERT, NEW n'existe pas pour un DELETE :
  -- on ne lit chacun que lorsqu'il a un sens.
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_avant := to_jsonb(OLD) - 'geom';   -- tous les attributs, sauf la géométrie
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_apres := to_jsonb(NEW) - 'geom';
  END IF;

  INSERT INTO labo.journal (table_nom, operation, avant, apres, geom_avant, geom_apres)
  VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,   -- variables fournies par PostgreSQL
          TG_OP,
          v_avant,
          v_apres,
          CASE WHEN TG_OP <> 'INSERT' THEN OLD.geom END,
          CASE WHEN TG_OP <> 'DELETE' THEN NEW.geom END);

  RETURN NULL;   -- dans un AFTER, la valeur de retour est ignorée
END;
$$;

-- AFTER : on journalise ce qui a réellement été écrit
-- (après les éventuelles modifications et validations des BEFORE)
CREATE TRIGGER trg_stations_journal
  AFTER INSERT OR UPDATE OR DELETE
  ON labo.stations
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_journaliser();

-- La MÊME fonction sur une autre table
CREATE TRIGGER trg_quartiers_journal
  AFTER INSERT OR UPDATE OR DELETE
  ON labo.quartiers
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_journaliser();


-- ---------------------------------------------------------------------
-- Essais
-- ---------------------------------------------------------------------
-- Ajouter une station fictive
INSERT INTO labo.stations (name, routes, geom)
VALUES ('Station test', 'Z', ST_GeomFromText('POINT(585000 4510000)', 26918));

-- La renommer et la déplacer de 50 m vers l'est
UPDATE labo.stations
SET name = 'Station test (déplacée)',
    geom = ST_Translate(geom, 50, 0)
WHERE name = 'Station test';

-- La supprimer
DELETE FROM labo.stations WHERE name LIKE 'Station test%';

-- Le journal a tout gardé
SELECT id, quand, qui, table_nom, operation,
       avant ->> 'name' AS nom_avant,
       apres ->> 'name' AS nom_apres,
       round(ST_Distance(geom_avant, geom_apres)) AS deplacement_m
FROM labo.journal
ORDER BY id;


-- Quelles stations ont été modifiées aujourd'hui, et par qui ?
SELECT qui, operation, count(*)
FROM labo.journal
WHERE quand::date = current_date
GROUP BY qui, operation;


-- Un UPDATE de 129 lignes produit 129 lignes de journal :
-- un déclencheur FOR EACH ROW s'exécute une fois PAR LIGNE.
