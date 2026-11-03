-- =====================================================================
--  GEO7531 - Vues 05 : Les vues matérialisées
--  Section 6 du tutoriel
--
--  Une vue matérialisée EXÉCUTE sa requête une fois et STOCKE le
--  résultat, comme une table. Lecture rapide, mais résultat figé
--  jusqu'au prochain REFRESH.
-- =====================================================================

-- 1. Créer la vue matérialisée (la requête s'exécute maintenant)
DROP MATERIALIZED VIEW IF EXISTS atelier.mv_densite_quartiers;
CREATE MATERIALIZED VIEW atelier.mv_densite_quartiers AS
SELECT q.id,
       q.name,
       q.boroname,
       sum(i.popn_total) AS population,
       round((sum(i.popn_total) / (ST_Area(q.geom) / 1e6))::numeric) AS hab_km2,
       q.geom
FROM atelier.quartiers AS q
JOIN atelier.ilots AS i
  ON ST_Contains(q.geom, ST_PointOnSurface(i.geom))
GROUP BY q.id;

-- 2. Contrairement à une vue, on peut l'INDEXER
CREATE UNIQUE INDEX ON atelier.mv_densite_quartiers (id);   -- requis pour CONCURRENTLY
CREATE INDEX ON atelier.mv_densite_quartiers USING GIST (geom);


-- 3. Comparer la vitesse (regardez « Execution Time »)
EXPLAIN ANALYZE SELECT * FROM atelier.v_densite_quartiers;    -- recalcule tout
EXPLAIN ANALYZE SELECT * FROM atelier.mv_densite_quartiers;   -- lit le résultat stocké

-- Elle occupe de la place, comme une table
SELECT pg_size_pretty(pg_total_relation_size('atelier.mv_densite_quartiers')) AS taille;


-- 4. Le piège : le résultat est FIGÉ
-- On double la population de Manhattan dans les îlots…
UPDATE atelier.ilots SET popn_total = popn_total * 2 WHERE boroname = 'Manhattan';

SELECT 'vue' AS source, population FROM atelier.v_densite_quartiers  WHERE name = 'Chelsea'
UNION ALL
SELECT 'vue matérialisée', population FROM atelier.mv_densite_quartiers WHERE name = 'Chelsea';
-- la vue voit le changement ; la vue matérialisée montre encore l'ancienne valeur

-- 5. Rafraîchir
REFRESH MATERIALIZED VIEW atelier.mv_densite_quartiers;
-- Variante qui ne bloque pas les lecteurs pendant le calcul
-- (exige un index UNIQUE, créé à l'étape 2) :
REFRESH MATERIALIZED VIEW CONCURRENTLY atelier.mv_densite_quartiers;

SELECT population FROM atelier.mv_densite_quartiers WHERE name = 'Chelsea';   -- à jour

-- On remet les données d'origine, puis on rafraîchit encore
UPDATE atelier.ilots SET popn_total = popn_total / 2 WHERE boroname = 'Manhattan';
REFRESH MATERIALIZED VIEW atelier.mv_densite_quartiers;


-- 6. Matérialiser la fusion des arrondissements (ST_Union est coûteux)
DROP MATERIALIZED VIEW IF EXISTS atelier.mv_arrondissements;
CREATE MATERIALIZED VIEW atelier.mv_arrondissements AS
SELECT * FROM atelier.v_arrondissements;      -- on peut matérialiser une vue
CREATE UNIQUE INDEX ON atelier.mv_arrondissements (id);
CREATE INDEX ON atelier.mv_arrondissements USING GIST (geom);


-- 7. Liste des vues matérialisées et de leur état
SELECT schemaname, matviewname, ispopulated
FROM pg_matviews
WHERE schemaname = 'atelier';
