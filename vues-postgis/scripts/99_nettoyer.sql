-- =====================================================================
--  GEO7531 - Vues 99 : Tout effacer
--  Supprime le schéma atelier (tables, vues, vues matérialisées) et le
--  rôle partenaire_lecture. Les tables du cours (public) ne sont pas touchées.
-- =====================================================================
DROP SCHEMA IF EXISTS atelier CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'partenaire_lecture') THEN
    DROP OWNED BY partenaire_lecture;   -- retire ses droits dans cette base
    DROP ROLE partenaire_lecture;
  END IF;
END;
$$;
