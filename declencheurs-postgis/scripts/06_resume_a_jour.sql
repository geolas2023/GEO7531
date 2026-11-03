-- =====================================================================
--  GEO7531 - Déclencheurs 06 : Tenir un résumé à jour entre deux tables
--  Section 8 du tutoriel
--
--  Chaque quartier affiche son nombre de stations. Quand une station
--  est ajoutée, déplacée ou supprimée, le compte se met à jour seul.
-- =====================================================================

ALTER TABLE labo.quartiers ADD COLUMN IF NOT EXISTS nb_stations integer DEFAULT 0;

-- État initial (calculé une fois)
UPDATE labo.quartiers AS q
SET nb_stations = (SELECT count(*) FROM labo.stations AS s
                   WHERE ST_Contains(q.geom, s.geom));


CREATE OR REPLACE FUNCTION labo.f_stations_recompter()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  g_ancienne geometry;   -- position avant (UPDATE, DELETE)
  g_nouvelle geometry;   -- position après (INSERT, UPDATE)
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN g_ancienne := OLD.geom; END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN g_nouvelle := NEW.geom; END IF;

  -- On ne recompte que le ou les quartiers concernés (1 ou 2), pas les 129
  UPDATE labo.quartiers AS q
  SET nb_stations = (SELECT count(*) FROM labo.stations AS s
                     WHERE ST_Contains(q.geom, s.geom))
  WHERE ST_Contains(q.geom, g_ancienne)
     OR ST_Contains(q.geom, g_nouvelle);

  RETURN NULL;
END;
$$;

-- AFTER : la station doit déjà être écrite (ou effacée) pour être comptée
CREATE TRIGGER trg_stations_recompter
  AFTER INSERT OR DELETE OR UPDATE OF geom
  ON labo.stations
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_stations_recompter();


-- ---------------------------------------------------------------------
-- Essai : une nouvelle station dans Little Italy
-- ---------------------------------------------------------------------
SELECT name, nb_stations FROM labo.quartiers WHERE name = 'Little Italy';   -- avant

INSERT INTO labo.stations (name, routes, geom)
SELECT 'Nouvelle station', 'Q', ST_PointOnSurface(geom)
FROM labo.quartiers WHERE name = 'Little Italy';

SELECT name, nb_stations FROM labo.quartiers WHERE name = 'Little Italy';   -- +1

DELETE FROM labo.stations WHERE name = 'Nouvelle station';

SELECT name, nb_stations FROM labo.quartiers WHERE name = 'Little Italy';   -- revenu


-- Remarque : la mise à jour de labo.quartiers déclenche à son tour
-- trg_quartiers_horodater et trg_quartiers_journal (cascade de
-- déclencheurs). C'est voulu ici, mais à surveiller : voir la section 10.
