-- =====================================================================
--  GEO7531 - Extensions 02 : Activer les extensions de géomatique
--  À exécuter dans le Query Tool de pgAdmin, CONNECTÉ À VOTRE BASE
--  (une extension s'active base par base, jamais pour tout le serveur).
--
--  Prérequis : les extensions doivent être DISPONIBLES sur le serveur
--  (script 01). Sous Windows : Stack Builder → Spatial Extensions →
--  PostGIS Bundle. Voir la section 2 du README.
--
--  Il faut être superutilisateur (postgres) pour la plupart d'entre elles.
--  IF NOT EXISTS : le script peut être relancé sans erreur.
--  Exécutez-le bloc par bloc (sélection + F5) : si une extension n'est
--  pas disponible, seul son bloc échoue.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Le cœur de PostGIS (indispensable)
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;            -- geometry, geography, ST_*
CREATE EXTENSION IF NOT EXISTS postgis_raster;     -- type raster, ST_MapAlgebra… (séparé depuis PostGIS 3)
CREATE EXTENSION IF NOT EXISTS postgis_topology;   -- topologie : nœuds, arêtes, faces partagés
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;     -- géométrie 3D avancée : volumes, extrusion


-- ---------------------------------------------------------------------
-- B. Noms de lieux et adresses
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;      -- levenshtein, soundex, dmetaphone
CREATE EXTENSION IF NOT EXISTS pg_trgm;            -- similarité de chaînes + index rapide
CREATE EXTENSION IF NOT EXISTS unaccent;           -- enlever les accents (toponymes)
CREATE EXTENSION IF NOT EXISTS address_standardizer;          -- découper une adresse en éléments
CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;  -- règles d'adresses américaines

-- Géocodeur TIGER (États-Unis seulement). Dépend de postgis et fuzzystrmatch.
-- Il fonctionne pour normaliser des adresses ; pour géocoder, il faut en plus
-- charger les données TIGER (plusieurs Go). Facultatif pour le cours.
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;


-- ---------------------------------------------------------------------
-- C. Réseaux et itinéraires
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgrouting;          -- pgr_dijkstra, pgr_drivingDistance…


-- ---------------------------------------------------------------------
-- D. LiDAR (nuages de points)
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pointcloud;         -- types pcpoint et pcpatch
CREATE EXTENSION IF NOT EXISTS pointcloud_postgis; -- passerelle pointcloud <-> geometry


-- ---------------------------------------------------------------------
-- E. Lire des données externes sans les importer
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS ogr_fdw;            -- shapefile, GeoPackage, CSV, Excel… vus comme des tables
CREATE EXTENSION IF NOT EXISTS postgres_fdw;       -- tables d'une autre base PostgreSQL


-- ---------------------------------------------------------------------
-- F. Grilles hexagonales H3
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS h3;                 -- index hexagonal mondial d'Uber
CREATE EXTENSION IF NOT EXISTS h3_postgis;         -- fonctions H3 sur des geometry


-- ---------------------------------------------------------------------
-- G. Utilitaires PostgreSQL utiles en géomatique
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS hstore;             -- paires clé=valeur (étiquettes OpenStreetMap)
CREATE EXTENSION IF NOT EXISTS btree_gist;         -- index GiST mixte : attribut + géométrie


-- ---------------------------------------------------------------------
-- H. Extensions qui exigent une modification de postgresql.conf
--    (voir la section 4.8 du README) - laissées en commentaire
-- ---------------------------------------------------------------------
-- MobilityDB (trajectoires) : dans postgresql.conf, puis redémarrer le service :
--     shared_preload_libraries = 'postgis-3'
--     max_locks_per_transaction = 128
-- CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;

-- pg_stat_statements (repérer les requêtes lentes) : dans postgresql.conf :
--     shared_preload_libraries = 'pg_stat_statements'
--     (si les deux sont nécessaires : 'postgis-3,pg_stat_statements')
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- ---------------------------------------------------------------------
-- Vérification finale
-- ---------------------------------------------------------------------
SELECT e.extname AS extension, e.extversion AS version, n.nspname AS schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;
