-- =====================================================================
--  GEO7531 - Vues 01 : Première vue
--  Section 2 du tutoriel
-- =====================================================================

-- 1. Créer la vue : on donne un nom à une requête
CREATE VIEW atelier.v_quartiers_manhattan AS
SELECT id, name, geom
FROM atelier.quartiers
WHERE boroname = 'Manhattan';


-- 2. L'utiliser exactement comme une table
SELECT name FROM atelier.v_quartiers_manhattan ORDER BY name;

SELECT count(*) FROM atelier.v_quartiers_manhattan;   -- 28

SELECT name, round((ST_Area(geom) / 1e6)::numeric, 2) AS km2
FROM atelier.v_quartiers_manhattan
ORDER BY km2 DESC
LIMIT 3;


-- 3. Une vue est TOUJOURS à jour : elle relit la table à chaque utilisation
INSERT INTO atelier.quartiers (name, boroname, geom)
VALUES ('Quartier fictif', 'Manhattan',
        ST_Multi(ST_Buffer(ST_GeomFromText('POINT(585000 4512000)', 26918), 200)));

SELECT count(*) FROM atelier.v_quartiers_manhattan;   -- 29 : la vue le voit déjà

DELETE FROM atelier.quartiers WHERE name = 'Quartier fictif';

SELECT count(*) FROM atelier.v_quartiers_manhattan;   -- 28


-- 4. Une vue ne contient aucune donnée : sa taille sur le disque est nulle
SELECT pg_size_pretty(pg_relation_size('atelier.quartiers'))             AS table_quartiers,
       pg_size_pretty(pg_relation_size('atelier.v_quartiers_manhattan')) AS vue;
-- la vue occupe 0 octet : elle ne stocke que sa requête
