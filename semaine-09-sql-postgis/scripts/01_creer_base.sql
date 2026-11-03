-- =====================================================================
--  GEO7531 - Semaine 9 - 01 : Créer la base de données spatiale
--  Sections 4 et 5 de la présentation (diapositives 14 à 33)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Diapo 28 : la base nyc (onglet SQL de pgAdmin)
-- À exécuter depuis la base « postgres », pas depuis la base nyc.
-- ---------------------------------------------------------------------
-- DROP DATABASE nyc;

CREATE DATABASE nyc
    WITH
    OWNER = postgres
    ENCODING = 'UTF8';
--  Sur la capture de la diapo 28, la base est aussi créée avec
--  LC_COLLATE = 'en_CA.UTF-8' et LC_CTYPE = 'en_CA.UTF-8' (paramètres
--  régionaux Linux/macOS). Sous Windows, laissez les valeurs par défaut.

-- Ouvrez ensuite un Query Tool sur la base nyc (diapo 19)
-- ou, dans psql :  \c nyc


-- ---------------------------------------------------------------------
-- Diapo 20 : activer PostGIS dans la base nyc
-- ---------------------------------------------------------------------
CREATE EXTENSION postgis;


-- ---------------------------------------------------------------------
-- Diapo 21 : vérifier l'installation
-- ---------------------------------------------------------------------
SELECT postgis_full_version();


-- ---------------------------------------------------------------------
-- Diapo 22 : les extensions essentielles
-- ---------------------------------------------------------------------
-- IF NOT EXISTS : pas d'erreur si l'extension est déjà active
-- (postgis l'est depuis la diapo 20).
CREATE EXTENSION IF NOT EXISTS postgis;            -- géométries et fonctions spatiales
CREATE EXTENSION IF NOT EXISTS postgis_raster;     -- rasters : MNT, NDVI, images
CREATE EXTENSION IF NOT EXISTS postgis_topology;   -- modèle topologique : nœuds, arêtes, faces
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;      -- comparaison de chaînes (Levenshtein, Soundex)

-- Extensions installées dans la base :
SELECT extname, extversion FROM pg_extension ORDER BY extname;


-- ---------------------------------------------------------------------
-- Diapos 25 à 28 : restaurer nyc_data.backup
-- Se fait dans pgAdmin (clic droit sur la base nyc → Restore...)
-- Voir le tutoriel « Créer, restaurer et sauvegarder une base ».
-- ---------------------------------------------------------------------

-- Vérification après la restauration :
SELECT f_table_name, f_geometry_column, type, srid
FROM geometry_columns;


-- ---------------------------------------------------------------------
-- Diapos 29 à 33 : charger un shapefile (ogr2ogr, shp2pgsql)
-- Ce ne sont pas des commandes SQL : voir 00_charger_shapefile.bat
-- (Windows) ou 00_charger_shapefile.sh (macOS / Linux).
-- ---------------------------------------------------------------------
