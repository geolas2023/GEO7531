-- =====================================================================
--  GEO7531 - Extensions 01 : Qu'est-ce qui est disponible ? installé ?
--  À exécuter dans le Query Tool de pgAdmin (ou psql), sur votre base.
--  Ce script ne modifie rien : il ne fait que lire.
-- =====================================================================

-- Version du serveur PostgreSQL
SELECT version();

-- 1. Extensions de géomatique DISPONIBLES sur le serveur
--    (fichiers présents sur le disque, donc installables avec CREATE EXTENSION)
--    installed_version vide = disponible mais pas encore activée dans cette base
SELECT name, default_version, installed_version, comment
FROM pg_available_extensions
WHERE name IN (
  'postgis', 'postgis_raster', 'postgis_topology', 'postgis_sfcgal',
  'fuzzystrmatch', 'address_standardizer', 'address_standardizer_data_us',
  'postgis_tiger_geocoder', 'pgrouting', 'pointcloud', 'pointcloud_postgis',
  'ogr_fdw', 'postgres_fdw', 'h3', 'h3_postgis', 'mobilitydb', 'pg_sphere',
  'pg_trgm', 'unaccent', 'hstore', 'btree_gist', 'pg_stat_statements'
)
ORDER BY name;

-- 2. Extensions INSTALLÉES dans la base courante (équivaut à \dx dans psql)
SELECT e.extname    AS extension,
       e.extversion AS version,
       n.nspname    AS schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;

-- 3. Détail de PostGIS et de ses bibliothèques (GEOS, PROJ, GDAL, SFCGAL…)
--    Erreur « function postgis_full_version() does not exist » = PostGIS
--    n'est pas encore activé dans cette base : voir le script 02.
SELECT postgis_full_version();

-- 4. Bibliothèques préchargées (nécessaire pour mobilitydb et pg_stat_statements)
SHOW shared_preload_libraries;
