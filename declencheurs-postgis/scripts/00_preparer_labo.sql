-- =====================================================================
--  GEO7531 - Déclencheurs 00 : Préparer un bac à sable
--  À exécuter dans la base qui contient les données NYC.
--
--  On travaille sur des COPIES des tables du cours, dans un schéma
--  « labo » : les déclencheurs n'altèrent jamais les données originales.
--  Pour tout recommencer : 99_nettoyer.sql, puis ce script.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS labo;

-- Copie des quartiers
DROP TABLE IF EXISTS labo.quartiers CASCADE;
CREATE TABLE labo.quartiers AS
SELECT name, boroname, geom::geometry(MultiPolygon, 26918) AS geom
FROM public.nyc_neighborhoods;

ALTER TABLE labo.quartiers ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX quartiers_geom_idx ON labo.quartiers USING GIST (geom);

-- Copie des stations de métro
DROP TABLE IF EXISTS labo.stations CASCADE;
CREATE TABLE labo.stations AS
SELECT name, routes, geom::geometry(Point, 26918) AS geom
FROM public.nyc_subway_stations;

ALTER TABLE labo.stations ADD COLUMN id serial PRIMARY KEY;
CREATE INDEX stations_geom_idx ON labo.stations USING GIST (geom);

-- Vérification
SELECT 'quartiers' AS table_labo, count(*) FROM labo.quartiers
UNION ALL
SELECT 'stations', count(*) FROM labo.stations;
-- quartiers | 129
-- stations  | 491
