-- =====================================================================
--  GEO7531 - Semaine 9 - 06 : Projection des données
--  Sections 16 et 17 de la présentation (diapositives 153 à 168)
-- =====================================================================


-- =====================================================================
-- Section 16 - Projection des données
-- =====================================================================

-- Diapo 159 : quel est le SRID de nos stations de métro ?
SELECT ST_SRID(geom)
FROM nyc_subway_stations
LIMIT 1;
-- 26918

-- Diapo 161 : que signifie le SRID 26918 ?
-- Le SRID est une clé étrangère vers la table spatial_ref_sys (diapo 160).
SELECT srtext
FROM spatial_ref_sys
WHERE srid = 26918;
-- PROJCS["NAD83 / UTM zone 18N", … ]   (définition complète à la diapo 162)
-- Voir aussi : https://epsg.io/26918

-- Diapo 163 : les coordonnées géographiques (lon, lat) de la station Broad St
SELECT ST_AsText(ST_Transform(geom, 4326))
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- POINT(-74.0106714 40.7071048)


-- =====================================================================
-- Section 17 - Exercices de projection
-- =====================================================================

-- Diapo 165 : longueur de toutes les rues de New York, mesurée en UTM 18
SELECT Sum(ST_Length(geom))
FROM nyc_streets;
-- 10418904.7172

-- Diapo 166 : définition WKT du SRID 2831
SELECT srtext
FROM spatial_ref_sys
WHERE srid = 2831;
-- PROJCS["NAD83(HARN) / New York Long Island", …

-- Diapo 167 : longueur de toutes les rues, mesurée dans le SRID 2831
-- (State Plane Long Island)
SELECT Sum(ST_Length(ST_Transform(geom, 2831)))
FROM nyc_streets;
-- 10421993.706374

-- Diapo 168 : combien de rues traversent le 74e méridien ?
SELECT Count(*)
FROM nyc_streets
WHERE ST_Intersects(
        ST_Transform(geom, 4326),
        'SRID=4326;LINESTRING(-74 20, -74 60)'
      );
-- 223
