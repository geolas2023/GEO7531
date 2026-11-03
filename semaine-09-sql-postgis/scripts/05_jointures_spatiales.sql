-- =====================================================================
--  GEO7531 - Semaine 9 - 05 : Jointures spatiales
--  Sections 13 et 14 de la présentation (diapositives 128 à 152)
--
--  ST_SetSRID(c.geom, 26918) « harmonise » le SRID de c.geom : les
--  deux géométries comparées doivent avoir le même SRID. Si
--  nyc_census_blocks est déjà en 26918, la fonction ne change rien.
-- =====================================================================


-- =====================================================================
-- Section 13 - Jointures spatiales
-- =====================================================================

-- Diapo 131 : rappel - dans quel quartier se trouve la station Broad St ?
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918));

-- Diapo 132 : la même chose en une seule étape, avec une jointure spatiale
SELECT s.name, n.name, n.boroname
FROM nyc_neighborhoods AS n
JOIN nyc_subway_stations AS s
  ON ST_Contains(n.geom, s.geom)
WHERE s.name = 'Broad St';

-- Diapo 134 : population et composition raciale des quartiers de Manhattan
SELECT n.name AS neighborhood_name,
       SUM(c.popn_total) AS population,
       100 * SUM(c.popn_white) / SUM(c.popn_total) AS white_pct,
       100 * SUM(c.popn_black) / SUM(c.popn_total) AS black_pct
FROM nyc_neighborhoods AS n
JOIN nyc_census_blocks AS c
  ON ST_Intersects(n.geom, ST_SetSRID(c.geom, 26918))
WHERE n.boroname = 'Manhattan'
GROUP BY n.name
ORDER BY white_pct DESC;
-- Résultat complet à la diapo 135 (Carnegie Hill, West Village, …)

-- Diapo 137 : composition raciale de toute la ville de New York
SELECT 100.0 * SUM(popn_white) / SUM(popn_total) AS white_pct,
       100.0 * SUM(popn_black) / SUM(popn_total) AS black_pct,
       SUM(popn_total) AS popn_total
FROM nyc_census_blocks;
-- 44.00395007628105 | 25.546578900241613 | 8175032

-- Diapo 141 : les lignes de métro sont des chaînes séparées par des virgules
SELECT DISTINCT routes
FROM nyc_subway_stations;

-- Diapo 143 : toutes les combinaisons de lignes qui contiennent le train A
-- La fonction strpos(routes, 'A') renvoie la position de 'A' dans routes, 0 s'il n'y est pas
SELECT DISTINCT routes
FROM nyc_subway_stations AS subways
WHERE strpos(subways.routes, 'A') > 0;

-- Diapo 145 : population et composition à moins de 200 m des arrêts du train A
SELECT 100 * SUM(c.popn_white) / SUM(c.popn_total) AS white_pct,
       100 * SUM(c.popn_black) / SUM(c.popn_total) AS black_pct,
       SUM(popn_total) AS popn_total
FROM nyc_census_blocks AS c
JOIN nyc_subway_stations AS s
  ON ST_DWithin(
       ST_SetSRID(c.geom, 26918),   -- Harmoniser le SRID de c.geom
       s.geom,
       200
     )
WHERE strpos(s.routes, 'A') > 0;
-- Diapo 146 : 45,59 % de Blancs et 22,09 % de Noirs le long du train A,
-- contre 44,00 % et 25,55 % pour l'ensemble de New York.


-- =====================================================================
-- Section 14 - Exercices sur les jointures spatiales
-- =====================================================================

-- Diapo 149 : quelle station se trouve dans « Little Italy » ? Sur quelle ligne ?
SELECT s.name, s.routes
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
  ON ST_Contains(n.geom, s.geom)
WHERE n.name = 'Little Italy';
-- Spring St | 6

-- Diapo 150 : quels quartiers sont desservis par le train 6 ?
SELECT DISTINCT n.name, n.boroname
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
  ON ST_Contains(n.geom, s.geom)
WHERE strpos(s.routes, '6') > 0;
-- Midtown, Hunts Point, …

-- Diapo 151 : après le 11 septembre, combien de personnes ont dû être
-- évacuées de Battery Park ?
SELECT Sum(popn_total)
FROM nyc_neighborhoods AS n
JOIN nyc_census_blocks AS c
  ON ST_Intersects(n.geom, ST_SetSRID(c.geom, 26918))   -- Harmoniser le SRID de c.geom
WHERE n.name = 'Battery Park';
-- 17153

-- Diapo 152 : quel quartier a la plus forte densité de population (hab./km²) ?
SELECT n.name,
       1000000 * Sum(c.popn_total) / ST_Area(n.geom) AS popn_per_sqkm
FROM nyc_census_blocks AS c
JOIN nyc_neighborhoods AS n
  ON ST_Intersects(ST_SetSRID(c.geom, 26918), n.geom)   -- Harmoniser le SRID de c.geom
GROUP BY n.name, n.geom
ORDER BY popn_per_sqkm DESC;
-- North Sutton Area | 68435.13283772678
