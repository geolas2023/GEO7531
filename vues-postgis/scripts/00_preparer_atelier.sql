-- =====================================================================
--  GEO7531 - Vues 00 : Préparer un atelier
--  À exécuter dans la base qui contient les données NYC.
--
--  Les vues ne stockent rien et ne modifient rien… sauf les vues
--  modifiables (section 7), qui écrivent dans leurs tables. On travaille
--  donc sur des COPIES des tables du cours, dans un schéma « atelier ».
--  Pour tout recommencer : 99_nettoyer.sql, puis ce script.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS atelier;

-- Quartiers
DROP TABLE IF EXISTS atelier.quartiers CASCADE;
CREATE TABLE atelier.quartiers AS
SELECT name, boroname, geom::geometry(MultiPolygon, 26918) AS geom
FROM public.nyc_neighborhoods;
ALTER TABLE atelier.quartiers ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX ON atelier.quartiers USING GIST (geom);

-- Îlots de recensement
DROP TABLE IF EXISTS atelier.ilots CASCADE;
CREATE TABLE atelier.ilots AS
SELECT blkid, popn_total, popn_white, popn_black, boroname,
       geom::geometry(MultiPolygon, 26918) AS geom
FROM public.nyc_census_blocks;
ALTER TABLE atelier.ilots ADD PRIMARY KEY (blkid);
CREATE INDEX ON atelier.ilots USING GIST (geom);

-- Stations de métro
DROP TABLE IF EXISTS atelier.stations CASCADE;
CREATE TABLE atelier.stations AS
SELECT name, borough, routes, geom::geometry(Point, 26918) AS geom
FROM public.nyc_subway_stations;
ALTER TABLE atelier.stations ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX ON atelier.stations USING GIST (geom);

-- Rues
DROP TABLE IF EXISTS atelier.rues CASCADE;
CREATE TABLE atelier.rues AS
SELECT name, type, oneway, geom::geometry(MultiLineString, 26918) AS geom
FROM public.nyc_streets;
ALTER TABLE atelier.rues ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX ON atelier.rues USING GIST (geom);

-- Homicides
DROP TABLE IF EXISTS atelier.homicides CASCADE;
CREATE TABLE atelier.homicides AS
SELECT weapon, light_dark, year, geom::geometry(Point, 26918) AS geom
FROM public.nyc_homicides;
ALTER TABLE atelier.homicides ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX ON atelier.homicides USING GIST (geom);

-- Statistiques à jour pour le planificateur
ANALYZE atelier.quartiers;
ANALYZE atelier.ilots;
ANALYZE atelier.stations;
ANALYZE atelier.rues;
ANALYZE atelier.homicides;

-- Vérification
SELECT 'quartiers' AS table_atelier, count(*) FROM atelier.quartiers
UNION ALL SELECT 'ilots',     count(*) FROM atelier.ilots
UNION ALL SELECT 'stations',  count(*) FROM atelier.stations
UNION ALL SELECT 'rues',      count(*) FROM atelier.rues
UNION ALL SELECT 'homicides', count(*) FROM atelier.homicides;
-- 129 | 38 794 | 491 | 19 091 | 3 984
