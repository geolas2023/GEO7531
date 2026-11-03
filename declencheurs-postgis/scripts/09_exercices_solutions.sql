-- =====================================================================
--  GEO7531 - Déclencheurs 09 : Solutions des exercices
--  Section 12 du tutoriel. Essayez d'abord sans regarder !
-- =====================================================================


-- ---------------------------------------------------------------------
-- Exercice 1 : interdire la suppression des stations de la ligne A
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_proteger_ligne_a()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF strpos(OLD.routes, 'A') > 0 THEN
    RAISE EXCEPTION 'La station % (lignes %) dessert la ligne A : suppression interdite',
                    OLD.name, OLD.routes;
  END IF;
  RETURN OLD;   -- BEFORE DELETE : renvoyer OLD pour laisser la suppression se faire
END;
$$;

CREATE TRIGGER trg_stations_proteger_a
  BEFORE DELETE ON labo.stations
  FOR EACH ROW EXECUTE FUNCTION labo.f_proteger_ligne_a();

-- Essai : on tente de supprimer une station de la ligne A → refusé
DELETE FROM labo.stations
WHERE id = (SELECT id FROM labo.stations WHERE strpos(routes, 'A') > 0 LIMIT 1);


-- ---------------------------------------------------------------------
-- Exercice 2 : chaque station connaît son quartier
-- ---------------------------------------------------------------------
ALTER TABLE labo.stations ADD COLUMN IF NOT EXISTS quartier text;

CREATE OR REPLACE FUNCTION labo.f_stations_quartier()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  SELECT q.name INTO NEW.quartier
  FROM labo.quartiers AS q
  WHERE ST_Contains(q.geom, NEW.geom)
  LIMIT 1;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_stations_quartier
  BEFORE INSERT OR UPDATE OF geom ON labo.stations
  FOR EACH ROW EXECUTE FUNCTION labo.f_stations_quartier();

-- Remplir les stations existantes (réveille le déclencheur)
UPDATE labo.stations SET geom = geom;

SELECT quartier, count(*) FROM labo.stations
GROUP BY quartier ORDER BY count(*) DESC LIMIT 5;


-- ---------------------------------------------------------------------
-- Exercice 3 : refuser un déplacement de plus de 100 m
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_limiter_deplacement()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF ST_Distance(OLD.geom, NEW.geom) > 100 THEN
    RAISE EXCEPTION 'Station % : déplacement de % m refusé (maximum 100 m)',
                    NEW.name, round(ST_Distance(OLD.geom, NEW.geom));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_stations_limiter_deplacement
  BEFORE UPDATE OF geom ON labo.stations
  FOR EACH ROW
  WHEN (OLD.geom IS DISTINCT FROM NEW.geom)
  EXECUTE FUNCTION labo.f_limiter_deplacement();

UPDATE labo.stations SET geom = ST_Translate(geom, 30, 0)  WHERE name = 'Broad St';  -- accepté
UPDATE labo.stations SET geom = ST_Translate(geom, 500, 0) WHERE name = 'Broad St';  -- refusé


-- ---------------------------------------------------------------------
-- Exercice 4 : nombre de signalements par quartier, tenu à jour
-- ---------------------------------------------------------------------
ALTER TABLE labo.quartiers ADD COLUMN IF NOT EXISTS nb_signalements integer DEFAULT 0;

CREATE OR REPLACE FUNCTION labo.f_signalements_recompter()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_ancien text;
  v_nouveau text;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN v_ancien  := OLD.quartier; END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN v_nouveau := NEW.quartier; END IF;

  UPDATE labo.quartiers AS q
  SET nb_signalements = (SELECT count(*) FROM labo.signalements AS s
                         WHERE s.quartier = q.name)
  WHERE q.name IN (v_ancien, v_nouveau);
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_signalements_recompter
  AFTER INSERT OR UPDATE OR DELETE ON labo.signalements
  FOR EACH ROW EXECUTE FUNCTION labo.f_signalements_recompter();

-- On réutilise le quartier déjà calculé par trg_signalements_1_completer
-- plutôt que refaire un ST_Contains : comparer des noms coûte moins cher.
-- Piège : « UPDATE OF quartier » ne conviendrait pas ici. Cette option ne
-- regarde que les colonnes écrites dans le SET de la requête, pas celles
-- modifiées par un déclencheur BEFORE. Un signalement déplacé avec
-- SET lon = …, lat = … changerait de quartier sans être recompté.
INSERT INTO labo.signalements (description, lon, lat)
VALUES ('Graffiti', -73.9973, 40.7191);   -- Little Italy

SELECT name, nb_signalements FROM labo.quartiers WHERE nb_signalements > 0;
