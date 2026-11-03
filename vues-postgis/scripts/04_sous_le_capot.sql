-- =====================================================================
--  GEO7531 - Vues 04 : Ce que fait PostgreSQL avec une vue
--  Section 5 du tutoriel
-- =====================================================================

-- 1. La définition est conservée dans le catalogue : on peut la relire
SELECT pg_get_viewdef('atelier.v_stations_quartier'::regclass, true);

SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'atelier';


-- 2. À l'exécution, la vue est REMPLACÉE par sa requête
--    Le plan montre les tables d'origine et l'utilisation de leurs index :
EXPLAIN
SELECT * FROM atelier.v_stations_quartier
WHERE name = 'Broad St';
-- Le filtre name = 'Broad St' est appliqué directement sur atelier.stations,
-- puis l'index GiST de atelier.quartiers est utilisé pour ST_Contains.
-- PostgreSQL n'a PAS calculé toute la vue (491 stations) avant de filtrer.

-- La même requête, écrite sans vue, donne exactement le même plan :
EXPLAIN
SELECT s.id, s.name, s.routes, q.name, q.boroname, s.geom
FROM atelier.stations AS s
LEFT JOIN atelier.quartiers AS q ON ST_Contains(q.geom, s.geom)
WHERE s.name = 'Broad St';


-- 3. Conséquence : une vue n'est ni plus rapide ni plus lente que sa
--    requête. Elle est recalculée à CHAQUE lecture :
EXPLAIN ANALYZE SELECT * FROM atelier.v_densite_quartiers;
-- Relancez-la : le temps est à peu près le même à chaque fois.
