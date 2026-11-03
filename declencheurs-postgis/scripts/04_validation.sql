-- =====================================================================
--  GEO7531 - Déclencheurs 04 : Contrôler la qualité des données
--  Section 6 du tutoriel
--  Prérequis : script 03 (table labo.signalements)
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Refuser une saisie avec un message clair : RAISE EXCEPTION
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_signalements_valider()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.geom IS NULL THEN
    RAISE EXCEPTION 'Signalement « % » : position manquante', NEW.description
      USING HINT = 'Donnez lon et lat, ou une géométrie.';
  END IF;

  -- quartier a été rempli par trg_signalements_1_completer, qui
  -- s'exécute AVANT celui-ci (ordre alphabétique des noms : 1 puis 2)
  IF NEW.quartier IS NULL THEN
    RAISE EXCEPTION 'Le point (%, %) est hors des quartiers de New York', NEW.lon, NEW.lat
      USING HINT = 'Vérifiez l''ordre : ST_MakePoint(longitude, latitude).';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_signalements_2_valider
  BEFORE INSERT OR UPDATE
  ON labo.signalements
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_signalements_valider();


-- Essai 1 : latitude et longitude inversées → refusé
INSERT INTO labo.signalements (description, lon, lat)
VALUES ('Coordonnées inversées', 40.7484, -73.9857);
-- ERREUR: Le point (40.7484, -73.9857) est hors des quartiers de New York
-- ASTUCE : Vérifiez l'ordre : ST_MakePoint(longitude, latitude).

-- Essai 2 : un INSERT de plusieurs lignes est refusé EN ENTIER
-- si une seule ligne est rejetée (tout ou rien)
INSERT INTO labo.signalements (description, lon, lat) VALUES
  ('Valide : Times Square', -73.9855, 40.7580),
  ('Invalide : Montréal',   -73.5673, 45.5017);
-- ERREUR … Montréal : aucune des deux lignes n'est ajoutée

SELECT count(*) FROM labo.signalements WHERE description LIKE 'Valide%';   -- 0


-- ---------------------------------------------------------------------
-- B. Ignorer une ligne en silence : RETURN NULL dans un BEFORE
--    (à utiliser avec prudence : rien ne prévient l'utilisateur,
--     sauf un avertissement RAISE NOTICE)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_signalements_ignorer_doublons()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Même description à moins de 10 m d'un signalement existant ?
  IF EXISTS (
    SELECT 1 FROM labo.signalements AS s
    WHERE s.description = NEW.description
      AND ST_DWithin(s.geom, NEW.geom, 10)
  ) THEN
    RAISE NOTICE 'Doublon ignoré : « % »', NEW.description;
    RETURN NULL;   -- la ligne n'est PAS insérée, sans erreur
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_signalements_3_doublons
  BEFORE INSERT
  ON labo.signalements
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_signalements_ignorer_doublons();

-- Essai : on renvoie deux fois le même signalement
INSERT INTO labo.signalements (description, lon, lat)
VALUES ('Feu de circulation en panne', -73.9772, 40.7527);   -- INSERT 0 1
INSERT INTO labo.signalements (description, lon, lat)
VALUES ('Feu de circulation en panne', -73.9772, 40.7527);   -- INSERT 0 0 + NOTICE

SELECT count(*) FROM labo.signalements
WHERE description = 'Feu de circulation en panne';   -- 1


-- ---------------------------------------------------------------------
-- C. Réparer au lieu de refuser : géométries invalides des quartiers
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_quartiers_reparer()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT ST_IsValid(NEW.geom) THEN
    RAISE NOTICE 'Quartier « % » : géométrie invalide (%), réparée',
                 NEW.name, ST_IsValidReason(NEW.geom);
    NEW.geom := ST_Multi(ST_CollectionExtract(ST_MakeValid(NEW.geom), 3));
  END IF;
  RETURN NEW;
END;
$$;

-- Nom choisi pour passer AVANT trg_quartiers_mesurer (« a » < « h » < « m ») :
-- on répare d'abord, on mesure ensuite.
CREATE TRIGGER trg_quartiers_a_reparer
  BEFORE INSERT OR UPDATE OF geom
  ON labo.quartiers
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_quartiers_reparer();

-- Essai : un polygone « papillon » (ses côtés se croisent)
INSERT INTO labo.quartiers (name, boroname, geom)
VALUES ('Papillon', 'Test',
        ST_Multi(ST_GeomFromText('POLYGON((580000 4500000, 581000 4501000, 581000 4500000, 580000 4501000, 580000 4500000))', 26918)));
-- NOTICE: Quartier « Papillon » : géométrie invalide (Self-intersection…), réparée

SELECT name, ST_IsValid(geom), ST_NumGeometries(geom), superficie_km2
FROM labo.quartiers WHERE name = 'Papillon';   -- t | 2 | 0.500

DELETE FROM labo.quartiers WHERE name = 'Papillon';


-- ---------------------------------------------------------------------
-- Alternative sans déclencheur : la contrainte CHECK
-- Suffit quand la règle ne dépend que de la ligne elle-même.
-- ---------------------------------------------------------------------
-- ALTER TABLE labo.stations
--   ADD CONSTRAINT stations_geom_valide CHECK (ST_IsValid(geom));
