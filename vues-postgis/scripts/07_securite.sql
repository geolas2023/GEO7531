-- =====================================================================
--  GEO7531 - Vues 07 : Partager des données sans tout montrer
--  Section 8 du tutoriel
--
--  Scénario : un partenaire doit voir la population par quartier, mais
--  pas le détail des 38 794 îlots (données plus fines, plus sensibles).
--  On lui donne accès à une VUE, et pas à la table.
--  À exécuter en tant que postgres (superutilisateur).
-- =====================================================================

-- 1. Une vue agrégée, sans les îlots
CREATE OR REPLACE VIEW atelier.v_population_publique AS
SELECT id, name, boroname, population, geom
FROM atelier.v_densite_quartiers;

-- 2. Un rôle (groupe d'utilisateurs) qui ne peut que lire cette vue
DROP ROLE IF EXISTS partenaire_lecture;
CREATE ROLE partenaire_lecture NOLOGIN;

GRANT USAGE  ON SCHEMA atelier TO partenaire_lecture;
GRANT SELECT ON atelier.v_population_publique TO partenaire_lecture;
-- Aucun droit sur atelier.ilots ni atelier.quartiers.


-- 3. Essayer en se mettant « dans la peau » du partenaire
SET ROLE partenaire_lecture;

SELECT name, population FROM atelier.v_population_publique
ORDER BY population DESC LIMIT 3;        -- accepté

SELECT count(*) FROM atelier.ilots;      -- refusé
-- ERREUR: permission denied for table ilots

RESET ROLE;   -- redevenir postgres

-- Pourquoi la vue fonctionne-t-elle alors que le partenaire n'a pas accès
-- aux tables ? Par défaut, une vue lit ses tables avec les droits de son
-- PROPRIÉTAIRE (ici postgres), pas avec ceux de la personne qui l'interroge.


-- 4. PostgreSQL 15 et plus : security_invoker
--    La vue lit alors les tables avec les droits de l'UTILISATEUR.
--    Utile quand on veut une vue « pratique » qui ne contourne pas les droits.
CREATE OR REPLACE VIEW atelier.v_population_invoker
WITH (security_invoker = true) AS
SELECT name, population FROM atelier.v_densite_quartiers;

GRANT SELECT ON atelier.v_population_invoker TO partenaire_lecture;

SET ROLE partenaire_lecture;
SELECT * FROM atelier.v_population_invoker LIMIT 1;
-- ERREUR: permission denied for … : le partenaire n'a pas accès aux tables
RESET ROLE;


-- 5. Nettoyage du rôle (aussi fait par 99_nettoyer.sql)
-- REVOKE ALL ON ALL TABLES IN SCHEMA atelier FROM partenaire_lecture;
-- REVOKE USAGE ON SCHEMA atelier FROM partenaire_lecture;
-- DROP ROLE partenaire_lecture;
