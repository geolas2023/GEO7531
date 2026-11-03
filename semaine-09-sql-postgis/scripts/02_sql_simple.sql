-- =====================================================================
--  GEO7531 - Semaine 9 - 02 : SQL simple
--  Sections 7 et 8 de la présentation (diapositives 40 à 56)
--  À exécuter sur la base nyc (données NYC restaurées).
-- =====================================================================


-- =====================================================================
-- Section 7 - SQL simple
-- =====================================================================

-- Diapo 41 : le nom de tous les quartiers
SELECT name
FROM nyc_neighborhoods;

-- Diapos 42-43 : afficher les quartiers sur la carte de pgAdmin
-- (onglet Geometry Viewer). Les données sont en UTM 18N (SRID 26918) :
-- ST_Transform les convertit en latitude/longitude (SRID 4326) pour que
-- pgAdmin puisse placer un fond de carte dessous.
SELECT name,
       ST_Transform(geom, 4326)
FROM nyc_neighborhoods;

SELECT geom,
       ST_Transform(geom, 4326)
FROM nyc_neighborhoods;

-- Diapo 46 : quels sont les noms de tous les quartiers de Brooklyn ?
SELECT name
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';

-- Diapo 47 : le nombre de lettres dans les noms des quartiers de Brooklyn
SELECT char_length(name)
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';

-- Diapo 48 : nombre moyen de lettres et écart-type, à Brooklyn
SELECT avg(char_length(name)),
       stddev(char_length(name))
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';

-- Diapo 49 : nombre moyen de lettres, par arrondissement
SELECT boroname,
       avg(char_length(name))
FROM nyc_neighborhoods
GROUP BY boroname;


-- =====================================================================
-- Section 8 - Exercices SQL simples
-- =====================================================================

-- Diapo 51 : combien d'enregistrements contient la table nyc_streets ?
SELECT Count(*)
FROM nyc_streets;

-- Diapo 52 : combien de rues de New York commencent par un « B » ?
SELECT Count(*)
FROM nyc_streets
WHERE name LIKE 'B%';

-- Diapo 53 : quelle est la population de New York ?
SELECT Sum(popn_total) AS population
FROM nyc_census_blocks;

-- Diapo 54 : quelle est la population du Bronx ?
SELECT Sum(popn_total)
FROM nyc_census_blocks
WHERE boroname = 'The Bronx';

-- Diapo 55 : combien y a-t-il de quartiers dans chaque arrondissement ?
SELECT boroname, Count(*)
FROM nyc_neighborhoods
GROUP BY boroname;

-- Diapo 56 : pourcentage de la population « blanche » par arrondissement
SELECT boroname,
       100.0 * Sum(popn_white) / Sum(popn_total) AS pct
FROM nyc_census_blocks
GROUP BY boroname;
