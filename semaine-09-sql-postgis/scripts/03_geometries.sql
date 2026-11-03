-- =====================================================================
--  GEO7531 - Semaine 9 - 03 : Géométries
--  Sections 9 et 10 de la présentation (diapositives 57 à 96)
--  Les résultats attendus, tels qu'affichés dans la présentation,
--  sont indiqués en commentaire sous chaque requête.
-- =====================================================================


-- =====================================================================
-- Section 9 - Géométries
-- =====================================================================

-- Diapo 59 : créer une table avec une colonne géométrique
CREATE TABLE geometries (
  name varchar,
  geom geometry
);

-- Diapo 60 : insérer plusieurs types de géométries
INSERT INTO geometries (name, geom) VALUES
  ('Point', ST_GeomFromText('POINT(0 0)')),
  ('Linestring', ST_GeomFromText('LINESTRING(0 0, 1 1, 2 1, 2 2)')),
  ('Polygon', ST_GeomFromText('POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))')),
  ('PolygonWithHole', ST_GeomFromText('POLYGON((0 0, 3 0, 3 3, 0 3, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))')),
  ('Collection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(0 0), LINESTRING(0 0, 1 1, 2 2))'));
--  Voir aussi : http://postgis.net/workshops/postgis-intro/geometries.html

-- Diapo 61 : afficher les géométries sous forme de texte (WKT)
SELECT name, ST_AsText(geom)
FROM geometries;

-- Diapo 63 : la vue geometry_columns
SELECT *
FROM geometry_columns;

-- Diapo 65 : fonctions de métadonnées
SELECT name,
       ST_GeometryType(geom),
       ST_NDims(geom),
       ST_SRID(geom)
FROM geometries;


-- ----- Points --------------------------------------------------------

-- Diapo 68
SELECT ST_AsText(geom)
FROM geometries
WHERE name = 'Point';
-- POINT(0 0)

-- Diapo 69
SELECT ST_X(geom),
       ST_Y(geom)
FROM geometries
WHERE name = 'Point';
-- 0 | 0

-- Diapo 70
SELECT name,
       ST_AsText(geom)
FROM nyc_subway_stations
LIMIT 1;
-- Cortlandt St | POINT(583521 4507077)


-- ----- Lignes (LineString) -------------------------------------------

-- Diapo 72
SELECT ST_AsText(geom)
FROM geometries
WHERE name = 'Linestring';
-- LINESTRING(0 0,1 1,2 1,2 2)

-- Diapo 73
SELECT ST_Length(geom)
FROM geometries
WHERE name = 'Linestring';
-- 3.41421356237309

-- Diapo 74 : autres fonctions sur les lignes
SELECT ST_Length(geom),
       ST_AsText(ST_StartPoint(geom)),
       ST_AsText(ST_EndPoint(geom)),
       ST_NumPoints(geom)
FROM geometries
WHERE name = 'Linestring';


-- ----- Polygones -----------------------------------------------------

-- Diapo 77
SELECT ST_AsText(geom)
FROM geometries
WHERE name LIKE 'Polygon%';
-- Polygon         : POLYGON((0 0,1 0,1 1,0 1,0 0))
-- PolygonWithHole : POLYGON((0 0,3 0,3 3,0 3,0 0),(1 1,2 1,2 2,1 2,1 1))

-- Diapo 78 : autres fonctions sur les polygones
SELECT name,
       ST_Area(geom),
       ST_NumInteriorRings(geom),
       ST_AsText(ST_ExteriorRing(geom)),
       ST_AsText(ST_InteriorRingN(geom, 1)),   -- 1er anneau intérieur (NULL s'il n'y en a pas)
       ST_Perimeter(geom)
FROM geometries
WHERE name LIKE 'Polygon%';

-- Diapo 80
SELECT name, ST_Area(geom)
FROM geometries
WHERE name LIKE 'Polygon%';
-- Polygon         | 1
-- PolygonWithHole | 8    (carré de 3 × 3 = 9, moins le trou de 1)


-- ----- Formats de géométrie (diapos 81 à 83) -------------------------

-- Diapo 82 : lire du WKT 3D, l'afficher en WKT
SELECT ST_AsText(
         ST_GeometryFromText('LINESTRING(0 0 0,1 0 0,1 1 2)')
       );
-- LINESTRING Z (0 0 0,1 0 0,1 1 2)

-- Diapo 83 : lire du GML, l'afficher en GeoJSON
SELECT ST_AsGeoJSON(
         ST_GeomFromGML('<gml:Point><gml:coordinates>1,1</gml:coordinates></gml:Point>')
       );
-- {"type":"Point","coordinates":[1,1]}


-- ----- Construire une géométrie avec un SRID (diapos 84 à 89) --------
-- Six façons d'obtenir le même résultat : SRID=4326;POINT(1 1)

-- Diapo 84
SELECT ST_AsEWKT(ST_GeomFromText('POINT(1 1)', 4326));

-- Diapo 85
SELECT ST_AsEWKT(ST_SetSRID(ST_GeomFromText('POINT(1 1)'), 4326));

-- Diapo 86
SELECT ST_AsEWKT(ST_SetSRID(ST_MakePoint(1, 1), 4326));

-- Diapo 87
SELECT ST_AsEWKT(ST_SetSRID('POINT(1 1)'::geometry, 4326));

-- Diapo 88
SELECT ST_AsEWKT('SRID=4326;POINT(1 1)'::geometry);

-- Diapo 89 (ST_Point avec SRID : PostGIS 3.2 et plus)
SELECT ST_AsEWKT(ST_Point(1, 1, 4326));


-- =====================================================================
-- Section 10 - Exercices de géométrie
-- =====================================================================

-- Diapo 91 : superficie du quartier « West Village »
SELECT ST_Area(geom)
FROM nyc_neighborhoods
WHERE name = 'West Village';
-- 1044614.5296486   (m², car le SRID 26918 est en mètres)

-- Diapo 92 : type de géométrie et longueur de « Pelham St »
SELECT ST_GeometryType(geom),
       ST_Length(geom)
FROM nyc_streets
WHERE name = 'Pelham St';
-- ST_MultiLineString | 50.323

-- Diapo 93 : représentation GeoJSON de la station « Broad St »
SELECT ST_AsGeoJSON(geom, 0)
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- {"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:26918"}},
--  "coordinates":[583571,4506714]}
-- (Selon la version de PostGIS, la partie "crs" peut ne pas apparaître.)

-- Diapo 94 : longueur totale des rues de New York, en kilomètres
SELECT Sum(ST_Length(geom)) / 1000
FROM nyc_streets;
-- 10418.904717199996

-- Diapo 95 : superficie de Manhattan en acres (1 acre = 4047 m²)
SELECT Sum(ST_Area(geom)) / 4047
FROM nyc_census_blocks
WHERE boroname = 'Manhattan';
-- 14601.3987215548

-- Diapo 96 : la station de métro la plus à l'ouest
SELECT ST_X(geom), name
FROM nyc_subway_stations
ORDER BY ST_X(geom)
LIMIT 1;
-- 563292.1 | Tottenville
