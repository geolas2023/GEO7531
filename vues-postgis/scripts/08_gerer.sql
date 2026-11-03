-- =====================================================================
--  GEO7531 - Vues 08 : Lister, modifier, documenter, supprimer
--  Section 9 du tutoriel
-- =====================================================================


-- 1. Lister les vues et les vues matérialisées du schéma
SELECT 'vue' AS genre, table_name AS nom
FROM information_schema.views
WHERE table_schema = 'atelier'
UNION ALL
SELECT 'vue matérialisée', matviewname
FROM pg_matviews
WHERE schemaname = 'atelier'
ORDER BY genre, nom;
-- Dans psql : \dv atelier.*   et   \dm atelier.*


-- 2. Modifier une vue : CREATE OR REPLACE VIEW
--    Permis : changer le FROM/WHERE, ajouter des colonnes À LA FIN.
CREATE OR REPLACE VIEW atelier.v_quartiers_manhattan AS
SELECT id, name, geom,
       round((ST_Area(geom) / 1e6)::numeric, 2) AS km2   -- nouvelle colonne, à la fin
FROM atelier.quartiers
WHERE boroname = 'Manhattan';

--    Interdit : retirer, renommer, réordonner une colonne ou changer son type
CREATE OR REPLACE VIEW atelier.v_quartiers_manhattan AS
SELECT name, id, geom,                                     -- ordre changé
       round((ST_Area(geom) / 1e6)::numeric, 2) AS km2
FROM atelier.quartiers
WHERE boroname = 'Manhattan';
-- ERREUR: cannot change name of view column "id" to "name"
--   → il faut DROP VIEW puis CREATE VIEW
--   (retirer une colonne donne de même : cannot drop columns from view)


-- 3. Les dépendances : une table ne peut pas perdre une colonne utilisée
--    par une vue
ALTER TABLE atelier.quartiers DROP COLUMN boroname;
-- ERREUR: cannot drop column boroname of table atelier.quartiers because
--         other objects depend on it
-- DÉTAIL: view atelier.v_quartiers_manhattan depends on column boroname …

-- Quelles vues dépendent de la table atelier.quartiers ?
SELECT DISTINCT v.relname AS vue_dependante
FROM pg_depend AS d
JOIN pg_rewrite AS r ON r.oid = d.objid
JOIN pg_class   AS v ON v.oid = r.ev_class
WHERE d.refobjid = 'atelier.quartiers'::regclass
  AND v.oid <> 'atelier.quartiers'::regclass
ORDER BY 1;

-- ⚠ DROP TABLE … CASCADE ou ALTER TABLE … DROP COLUMN … CASCADE
--   supprime aussi toutes ces vues, sans autre avertissement.


-- 4. Le piège du SELECT * : la liste des colonnes est figée à la création
CREATE OR REPLACE VIEW atelier.v_stations_toutes AS
SELECT * FROM atelier.stations;

ALTER TABLE atelier.stations ADD COLUMN accessible boolean;

SELECT * FROM atelier.v_stations_toutes LIMIT 1;
-- pas de colonne « accessible » : la vue a mémorisé les colonnes
-- id, name, borough, routes, geom au moment du CREATE VIEW

ALTER TABLE atelier.stations DROP COLUMN accessible;
DROP VIEW atelier.v_stations_toutes;


-- 5. Documenter et renommer
COMMENT ON VIEW atelier.v_densite_quartiers IS
  'Population et densité (hab./km²) par quartier. Un îlot est attribué au quartier qui contient son ST_PointOnSurface.';

ALTER VIEW atelier.v_zones_500m RENAME TO v_stations_tampon_500m;

SELECT obj_description('atelier.v_densite_quartiers'::regclass);


-- 6. Supprimer
-- DROP VIEW IF EXISTS atelier.v_quartiers_manhattan;
-- DROP MATERIALIZED VIEW IF EXISTS atelier.mv_densite_quartiers;
-- DROP VIEW atelier.v_densite_quartiers;          -- refusé : d'autres vues en dépendent
-- DROP VIEW atelier.v_densite_quartiers CASCADE;  -- les supprime aussi
