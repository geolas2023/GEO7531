-- =====================================================================
--  GEO7531 - Déclencheurs 02 : Calculer des attributs géométriques
--  Section 4 du tutoriel
-- =====================================================================

ALTER TABLE labo.quartiers
  ADD COLUMN IF NOT EXISTS superficie_km2 numeric(10, 3),
  ADD COLUMN IF NOT EXISTS perimetre_km   numeric(10, 3);


CREATE OR REPLACE FUNCTION labo.f_quartiers_mesurer()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.superficie_km2 := ST_Area(NEW.geom) / 1e6;        -- m² → km²
  NEW.perimetre_km   := ST_Perimeter(NEW.geom) / 1e3;   -- m  → km
  RETURN NEW;
END;
$$;

-- UPDATE OF geom : le déclencheur ne s'exécute que si la colonne geom
-- figure dans le SET de l'UPDATE. Modifier le nom ne recalcule rien.
CREATE TRIGGER trg_quartiers_mesurer
  BEFORE INSERT OR UPDATE OF geom
  ON labo.quartiers
  FOR EACH ROW
  EXECUTE FUNCTION labo.f_quartiers_mesurer();


-- Remplir les lignes EXISTANTES : un déclencheur n'agit que sur les
-- opérations futures. On « touche » la géométrie pour le faire réagir.
UPDATE labo.quartiers SET geom = geom;

SELECT name, superficie_km2, perimetre_km
FROM labo.quartiers
ORDER BY superficie_km2 DESC
LIMIT 5;


-- Essai : on simplifie la géométrie de Central Park (tolérance 50 m)
-- → la superficie et le périmètre sont recalculés automatiquement
SELECT name, superficie_km2, perimetre_km
FROM labo.quartiers WHERE name = 'Central Park';

UPDATE labo.quartiers
SET geom = ST_Multi(ST_Simplify(geom, 50))
WHERE name = 'Central Park';

SELECT name, superficie_km2, perimetre_km
FROM labo.quartiers WHERE name = 'Central Park';


-- Remarque : chaque UPDATE ci-dessus a aussi déclenché
-- trg_quartiers_horodater (script 01). Plusieurs déclencheurs peuvent
-- réagir au même événement ; ils s'exécutent par ordre alphabétique
-- de nom : trg_quartiers_horodater, puis trg_quartiers_mesurer.


-- ---------------------------------------------------------------------
-- Alternative sans déclencheur : la colonne générée (PostgreSQL 12+)
-- Possible quand le calcul ne dépend QUE de la ligne elle-même.
-- ---------------------------------------------------------------------
-- ALTER TABLE labo.quartiers
--   ADD COLUMN superficie_km2_gen numeric
--   GENERATED ALWAYS AS (ST_Area(geom) / 1e6) STORED;
