-- =====================================================================
--  GEO7531 - 01 : Préparer la base de données
--  À exécuter dans le Query Tool de pgAdmin, connecté à la base geo7531
--  (ou dans psql : \i C:/GEO7531/scripts/01_preparer_base.sql)
--
--  La base elle-même se crée AVANT, depuis la base "postgres" :
--      CREATE DATABASE geo7531;
-- =====================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;          -- géométries
CREATE EXTENSION IF NOT EXISTS postgis_raster;   -- rasters (PostGIS 3+)

-- Facultatif : nuages de points LiDAR (section 9).
-- Décommentez si l'extension est disponible sur votre serveur.
-- CREATE EXTENSION IF NOT EXISTS pointcloud;
-- CREATE EXTENSION IF NOT EXISTS pointcloud_postgis;

-- Schémas de travail
CREATE SCHEMA IF NOT EXISTS vecteur;   -- données vectorielles importées
CREATE SCHEMA IF NOT EXISTS raster;    -- données matricielles importées
CREATE SCHEMA IF NOT EXISTS travaux;   -- résultats de traitements
CREATE SCHEMA IF NOT EXISTS lidar;     -- nuages de points

-- Vérifications
SELECT postgis_full_version();   -- doit mentionner RASTER
SELECT extname, extversion FROM pg_extension ORDER BY extname;
SELECT nspname AS schema FROM pg_namespace
WHERE nspname IN ('vecteur', 'raster', 'travaux', 'lidar');
