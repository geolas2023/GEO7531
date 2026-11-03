-- =====================================================================
--  GEO7531 - Déclencheurs 03 : Une jointure spatiale automatique
--  Section 5 du tutoriel
--
--  Scénario : une application citoyenne enregistre des signalements
--  (nid-de-poule, lampadaire brisé…). On saisit seulement une description
--  et une position ; le déclencheur complète tout le reste.
-- =====================================================================

DROP TABLE IF EXISTS labo.signalements CASCADE;
CREATE TABLE labo.signalements (
  id              serial PRIMARY KEY,
  description     text NOT NULL,
  lon             double precision,             -- longitude WGS 84
  lat             double precision,             -- latitude WGS 84
  geom            geometry(Point, 26918),       -- position en UTM 18N
  quartier        text,
  arrondissement  text,
  station_proche  text,
  dist_station_m  integer,
  cree_le         timestamptz DEFAULT now()
);
CREATE INDEX signalements_geom_idx ON labo.signalements USING GIST (geom);


CREATE OR REPLACE FUNCTION labo.f_signalements_completer()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- 1. Synchroniser les deux façons de donner la position --------------
  --    a) saisie en lon/lat (formulaire, GPS) : on construit geom
  --    b) saisie de geom (point dessiné dans QGIS) : on calcule lon/lat
  IF TG_OP = 'INSERT' THEN
    IF NEW.geom IS NULL AND NEW.lon IS NOT NULL AND NEW.lat IS NOT NULL THEN
      NEW.geom := ST_Transform(ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326), 26918);
    END IF;
  ELSE  -- UPDATE
    IF NEW.geom IS DISTINCT FROM OLD.geom THEN
      NULL;  -- la géométrie a été déplacée : lon/lat seront recalculés plus bas
    ELSIF NEW.lon IS DISTINCT FROM OLD.lon OR NEW.lat IS DISTINCT FROM OLD.lat THEN
      NEW.geom := ST_Transform(ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326), 26918);
    END IF;
  END IF;

  IF NEW.geom IS NULL THEN
    RETURN NEW;   -- pas de position : rien d'autre à calculer
  END IF;

  NEW.lon := round(ST_X(ST_Transform(NEW.geom, 4326))::numeric, 6);
  NEW.lat := round(ST_Y(ST_Transform(NEW.geom, 4326))::numeric, 6);

  -- 2. Jointure spatiale : dans quel quartier ? -------------------------
  --    SELECT … INTO remplit directement les champs de NEW.
  --    Si aucun quartier ne contient le point, ils restent NULL.
  SELECT q.name, q.boroname
    INTO NEW.quartier, NEW.arrondissement
  FROM labo.quartiers AS q
  WHERE ST_Contains(q.geom, NEW.geom)
  LIMIT 1;

  -- 3. Plus proche voisin : quelle station ? ----------------------------
  SELECT s.name, round(ST_Distance(s.geom, NEW.geom))
    INTO NEW.station_proche, NEW.dist_station_m
  FROM labo.stations AS s
  ORDER BY s.geom <-> NEW.geom
  LIMIT 1;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_signalements_1_completer
  BEFORE INSERT OR UPDATE
  ON labo.signalements
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_signalements_completer();


-- ---------------------------------------------------------------------
-- Essais
-- ---------------------------------------------------------------------
-- a) Saisie en longitude / latitude
INSERT INTO labo.signalements (description, lon, lat) VALUES
  ('Nid-de-poule devant l''Empire State Building', -73.9857, 40.7484),
  ('Lampadaire brisé près du Yankee Stadium',     -73.9262, 40.8296);

-- b) Saisie d'une géométrie (comme un point dessiné dans QGIS)
INSERT INTO labo.signalements (description, geom) VALUES
  ('Banc endommagé, Broad St', ST_GeomFromText('POINT(583571 4506714)', 26918));

SELECT id, description, lon, lat, quartier, arrondissement,
       station_proche, dist_station_m
FROM labo.signalements;

-- c) Déplacer un signalement en modifiant lon/lat : tout est recalculé
UPDATE labo.signalements
SET lon = -73.9654, lat = 40.7829          -- Central Park
WHERE id = 1;

SELECT id, quartier, station_proche, dist_station_m, ST_AsText(geom, 0)
FROM labo.signalements WHERE id = 1;
