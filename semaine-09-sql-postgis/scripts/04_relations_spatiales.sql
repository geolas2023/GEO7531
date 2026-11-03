-- =====================================================================
--  GEO7531 - Semaine 9 - 04 : Relations spatiales
--  Sections 11 et 12 de la présentation (diapositives 97 à 127)
-- =====================================================================


-- =====================================================================
-- Section 11 - Relations spatiales
-- =====================================================================

-- Diapo 105 : quelle est la géométrie de la station Broad St ?
SELECT name, geom
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- 0101000020266900000EEBD4CF27CF2141BC17D69516315141   (format EWKB hexadécimal)

-- Diapo 106 : quelle station correspond à cette géométrie ? (ST_Equals)
SELECT name
FROM nyc_subway_stations
WHERE ST_Equals(
        geom,
        '0101000020266900000EEBD4CF27CF2141BC17D69516315141');
-- Broad St

-- Diapo 108 : le texte connu (WKT) de la station Broad St
SELECT name, ST_AsText(geom, 0)
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- POINT(583571 4506714)

-- Diapo 109 : quel quartier croise cette station ? (ST_Intersects)
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918));
-- Financial District | Manhattan

-- Diapo 115 : ST_Distance entre un point et une ligne
SELECT ST_Distance(
         ST_GeomFromText('POINT(0 5)'),
         ST_GeomFromText('LINESTRING(-2 2, 2 2)')
       );
-- 3

-- Diapo 117 : les rues à moins de 10 m de la station Broad St (ST_DWithin)
SELECT name, geom
FROM nyc_streets
WHERE ST_DWithin(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918),
        10
      );
-- Wall St, Broad St, Nassau St (carte de la diapo 118)


-- =====================================================================
-- Section 12 - Exercices sur les relations spatiales
-- =====================================================================

-- Diapo 120 : le texte connu de la rue « Atlantic Commons »
SELECT ST_AsText(geom, 0)
FROM nyc_streets
WHERE name = 'Atlantic Commons';
-- MULTILINESTRING((586782 4504202,586864 4504216))

-- Diapo 121 : dans quel quartier et quel arrondissement se trouve
-- POINT(586782 4504202) ?
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(586782 4504202)', 26918));

-- Diapo 122 : combien de personnes vivent à moins de 50 m de
-- POINT(586782 4504202) ?
SELECT Sum(popn_total)
FROM nyc_census_blocks
WHERE ST_DWithin(
        ST_SetSRID(geom, 26918),
        ST_GeomFromText('POINT(586782 4504202)', 26918),
        50
      );

-- Diapos 123 à 125 : pour LINESTRING(0 0, 2 2) et POINT(1 1),
-- quelles relations sont vraies ?
SELECT ST_Intersects(l, p), ST_Touches(l, p),
       ST_Contains(l, p),   ST_Disjoint(l, p),
       ST_Overlaps(l, p),   ST_Crosses(l, p),
       ST_Within(l, p)
FROM (
  SELECT 'LINESTRING(0 0, 2 2)'::geometry AS l,
         'POINT(1 1)'::geometry AS p
) AS subquery;
-- st_intersects | t
-- st_touches    | f
-- st_contains   | t
-- st_disjoint   | f
-- st_overlaps   | f
-- st_crosses    | f
-- st_within     | f

-- Diapo 127 : quelle est la distance entre « Columbus Cir » et « Fulton Ave » ?
SELECT ST_Distance(a.geom, b.geom)
FROM nyc_streets a,
     nyc_streets b
WHERE a.name = 'Fulton Ave'
  AND b.name = 'Columbus Cir';
