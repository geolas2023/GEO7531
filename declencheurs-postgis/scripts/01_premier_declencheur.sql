-- =====================================================================
--  GEO7531 - Déclencheurs 01 : Premier déclencheur - horodater
--  Section 2 du tutoriel
-- =====================================================================

-- 1. Les colonnes à remplir automatiquement
ALTER TABLE labo.quartiers
  ADD COLUMN IF NOT EXISTS modifie_le  timestamptz,
  ADD COLUMN IF NOT EXISTS modifie_par text;


-- 2. La FONCTION : ce qu'il faut faire
--    - RETURNS trigger : c'est une fonction de déclencheur
--    - NEW : la ligne telle qu'elle va être écrite (modifiable en BEFORE)
--    - RETURN NEW : « continue, et écris cette version de la ligne »
CREATE OR REPLACE FUNCTION labo.f_horodater()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.modifie_le  := now();
  NEW.modifie_par := current_user;
  RETURN NEW;
END;
$$;


-- 3. Le DÉCLENCHEUR : quand appeler la fonction
CREATE TRIGGER trg_quartiers_horodater
  BEFORE INSERT OR UPDATE            -- avant l'écriture, à l'ajout ou à la modification
  ON labo.quartiers                  -- sur cette table
  FOR EACH ROW                       -- une fois par ligne touchée
  EXECUTE FUNCTION labo.f_horodater();


-- 4. Essai : on modifie un quartier SANS mentionner modifie_le
UPDATE labo.quartiers
SET name = 'SoHo'
WHERE name = 'Soho';

SELECT id, name, modifie_le, modifie_par
FROM labo.quartiers
WHERE name = 'SoHo';
-- modifie_le et modifie_par sont remplis : c'est le déclencheur qui l'a fait

-- Les autres quartiers n'ont pas été touchés : modifie_le est vide
SELECT count(*) AS jamais_modifies
FROM labo.quartiers
WHERE modifie_le IS NULL;   -- 128
