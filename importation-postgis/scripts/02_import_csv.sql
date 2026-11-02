-- =====================================================================
--  GEO7531 - 02 : Importer un CSV avec \copy puis créer la géométrie
--  À exécuter dans psql (PAS dans le Query Tool : \copy est une
--  méta-commande psql). Exemple :
--      psql -h localhost -U postgres -d geo7531 -f 02_import_csv.sql
--  Adaptez le chemin du fichier CSV ci-dessous (utilisez des / ).
-- =====================================================================

\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS vecteur;
DROP TABLE IF EXISTS vecteur.stations;

-- 1) Table dont les colonnes suivent l'ordre du fichier CSV
CREATE TABLE vecteur.stations (
    id          integer PRIMARY KEY,
    nom         text,
    longitude   double precision,
    latitude    double precision,
    achalandage integer
);

-- 2) Importation (la commande \copy doit tenir sur UNE seule ligne)
\copy vecteur.stations FROM 'C:/GEO7531/importation-postgis/donnees_exemple/stations_exemple.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8')

-- 3) Géométrie : point WGS84 (lon, lat) reprojeté en NAD83 / MTM 8
ALTER TABLE vecteur.stations ADD COLUMN geom geometry(Point, 32188);

UPDATE vecteur.stations
SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 32188);

-- 4) Index spatial + statistiques
CREATE INDEX stations_geom_idx ON vecteur.stations USING gist (geom);
ANALYZE vecteur.stations;

-- 5) Vérification
SELECT id, nom, achalandage, ST_AsText(geom) AS geom_mtm8
FROM vecteur.stations
ORDER BY id;

-- 6) Exemple : stations à moins de 1 km de Berri-UQAM
SELECT s.nom,
       round(ST_Distance(s.geom, b.geom)::numeric, 0) AS distance_m
FROM vecteur.stations s,
     (SELECT geom FROM vecteur.stations WHERE nom = 'Berri-UQAM') b
WHERE ST_DWithin(s.geom, b.geom, 1000)
ORDER BY distance_m;

-- 7) Export d'une requête vers un CSV
\copy (SELECT nom, achalandage FROM vecteur.stations ORDER BY achalandage DESC) TO 'C:/GEO7531/export_stations.csv' WITH (FORMAT csv, HEADER true)
