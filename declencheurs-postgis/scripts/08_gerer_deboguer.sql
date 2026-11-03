-- =====================================================================
--  GEO7531 - Déclencheurs 08 : Lister, désactiver, modifier, supprimer
--  Section 10 du tutoriel
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Quels déclencheurs existent dans le schéma labo ?
--    (dans psql : \d labo.quartiers les liste aussi, en bas)
-- ---------------------------------------------------------------------
SELECT event_object_table AS table_nom,
       trigger_name       AS declencheur,
       action_timing      AS moment,       -- BEFORE, AFTER, INSTEAD OF
       string_agg(event_manipulation, ' OR ' ORDER BY event_manipulation) AS evenements,
       action_orientation AS niveau,       -- ROW ou STATEMENT
       action_statement   AS action
FROM information_schema.triggers
WHERE trigger_schema = 'labo'
GROUP BY 1, 2, 3, 5, 6
ORDER BY table_nom, declencheur;   -- ordre alphabétique = ordre d'exécution

-- Avec leur état (activé ou non)
SELECT tgrelid::regclass AS table_nom,
       tgname           AS declencheur,
       CASE tgenabled WHEN 'D' THEN 'désactivé' ELSE 'activé' END AS etat
FROM pg_trigger
WHERE NOT tgisinternal
  AND tgrelid::regclass::text LIKE 'labo.%'
ORDER BY 1, 2;


-- ---------------------------------------------------------------------
-- 2. Lire le code d'une fonction de déclencheur
-- ---------------------------------------------------------------------
SELECT pg_get_functiondef('labo.f_signalements_completer'::regproc);


-- ---------------------------------------------------------------------
-- 3. Désactiver temporairement (par exemple pendant un gros chargement)
-- ---------------------------------------------------------------------
ALTER TABLE labo.quartiers DISABLE TRIGGER trg_quartiers_journal;   -- un seul
-- … chargement ou correction massive sans journal …
ALTER TABLE labo.quartiers ENABLE TRIGGER trg_quartiers_journal;

ALTER TABLE labo.stations DISABLE TRIGGER USER;   -- tous ceux créés par les utilisateurs
ALTER TABLE labo.stations ENABLE TRIGGER USER;
-- (DISABLE TRIGGER ALL désactive aussi les contraintes de clés étrangères :
--  réservé aux superutilisateurs, à éviter)


-- ---------------------------------------------------------------------
-- 4. Modifier
-- ---------------------------------------------------------------------
-- Modifier ce que FAIT le déclencheur : CREATE OR REPLACE FUNCTION
-- (le déclencheur utilise la nouvelle version immédiatement).

-- Modifier QUAND il se déclenche : le recréer.
-- PostgreSQL 14 et plus : CREATE OR REPLACE TRIGGER
CREATE OR REPLACE TRIGGER trg_quartiers_horodater
  BEFORE UPDATE                        -- n'horodate plus les INSERT
  ON labo.quartiers
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_horodater();

-- Avant PostgreSQL 14 : DROP TRIGGER puis CREATE TRIGGER


-- ---------------------------------------------------------------------
-- 5. Condition WHEN : ne se déclencher que si c'est utile
--    La condition est évaluée AVANT d'appeler la fonction : plus rapide
--    qu'un IF au début de la fonction.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_quartiers_horodater
  BEFORE UPDATE
  ON labo.quartiers
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)  -- seulement si quelque chose change vraiment
  EXECUTE FUNCTION labo.f_horodater();

-- (Dans WHEN, OLD n'existe pas pour INSERT et NEW pas pour DELETE.)


-- ---------------------------------------------------------------------
-- 6. Déboguer : RAISE NOTICE affiche un message (onglet Messages de pgAdmin)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION labo.f_espion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE NOTICE 'Déclencheur % : % % sur %.% (profondeur %)',
               TG_NAME, TG_WHEN, TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME,
               pg_trigger_depth();
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_stations_0_espion
  BEFORE INSERT OR UPDATE OR DELETE
  ON labo.stations
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_espion();

UPDATE labo.stations SET routes = routes WHERE name = 'Broad St';
-- NOTICE: Déclencheur trg_stations_0_espion : BEFORE UPDATE sur labo.stations (profondeur 1)

DROP TRIGGER trg_stations_0_espion ON labo.stations;
DROP FUNCTION labo.f_espion();


-- ---------------------------------------------------------------------
-- 7. Supprimer
-- ---------------------------------------------------------------------
-- DROP TRIGGER IF EXISTS trg_quartiers_horodater ON labo.quartiers;
-- DROP FUNCTION IF EXISTS labo.f_horodater();
-- (Une fonction utilisée par un déclencheur ne peut pas être supprimée
--  sans CASCADE, qui supprime aussi le déclencheur.)
