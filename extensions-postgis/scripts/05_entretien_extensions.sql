-- =====================================================================
--  GEO7531 - Extensions 05 : Mettre à jour, déplacer, supprimer
--  À exécuter dans le Query Tool, sur la base concernée.
--  Lisez chaque bloc avant de l'exécuter : certains sont destructifs.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Après une mise à jour de PostGIS sur le serveur
--    (nouveau Bundle installé avec Stack Builder, nouveau paquet Linux…)
--    Les fichiers sont à jour, mais chaque BASE garde l'ancienne version
--    tant qu'on ne la met pas à jour.
-- ---------------------------------------------------------------------

-- Versions installées dans la base et versions disponibles sur le serveur
SELECT name, installed_version, default_version,
       installed_version IS DISTINCT FROM default_version AS a_mettre_a_jour
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
ORDER BY name;

-- Met à jour d'un coup postgis, postgis_raster, postgis_topology,
-- postgis_sfcgal et postgis_tiger_geocoder
SELECT postgis_extensions_upgrade();

-- Les autres extensions se mettent à jour une par une
ALTER EXTENSION pgrouting UPDATE;
-- ALTER EXTENSION h3 UPDATE;
-- ALTER EXTENSION h3_postgis UPDATE;
-- ALTER EXTENSION pointcloud UPDATE;
-- ALTER EXTENSION pointcloud_postgis UPDATE;
-- ALTER EXTENSION ogr_fdw UPDATE;


-- ---------------------------------------------------------------------
-- 2. Installer une extension dans un schéma dédié (facultatif)
--    Garde le schéma public propre : les fonctions vont ailleurs.
--    À faire AVANT de créer des tables qui en dépendent.
-- ---------------------------------------------------------------------
-- CREATE SCHEMA IF NOT EXISTS extensions;
-- CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA extensions;
-- ALTER DATABASE geo7531 SET search_path = public, extensions;
-- (Se reconnecter pour que le nouveau search_path s'applique.)
--
-- PostGIS lui-même : laissez-le dans public, c'est ce qu'attendent
-- QGIS, ArcGIS Pro, shp2pgsql et les sauvegardes du cours.


-- ---------------------------------------------------------------------
-- 3. Une base « modèle » avec toutes les extensions déjà activées
--    Pratique pour créer une base par TP sans tout réactiver.
--    À exécuter depuis la base postgres (pas depuis la base modèle).
-- ---------------------------------------------------------------------
-- CREATE DATABASE modele_geo7531;
-- \c modele_geo7531          (psql) ou ouvrez un Query Tool sur cette base
-- CREATE EXTENSION postgis; CREATE EXTENSION postgis_raster; …
--
-- Ensuite, chaque nouvelle base hérite des extensions :
-- CREATE DATABASE tp1 TEMPLATE modele_geo7531;
-- (Personne ne doit être connecté à modele_geo7531 pendant cette commande.)


-- ---------------------------------------------------------------------
-- 4. Supprimer une extension
--    ⚠ DROP EXTENSION … CASCADE supprime AUSSI tout ce qui en dépend :
--    DROP EXTENSION postgis CASCADE efface toutes les colonnes geometry
--    de la base, avec leurs données. Faites une sauvegarde avant.
-- ---------------------------------------------------------------------
-- Voir d'abord ce qui dépend d'une extension (ici pgrouting) :
SELECT p.proname AS fonction
FROM pg_depend d
JOIN pg_extension e ON e.oid = d.refobjid
JOIN pg_proc p ON p.oid = d.objid
WHERE e.extname = 'pgrouting'
LIMIT 10;

-- Sans CASCADE : refuse de supprimer si quelque chose en dépend (prudent)
-- DROP EXTENSION IF EXISTS pgrouting;


-- ---------------------------------------------------------------------
-- 5. Sauvegarde et restauration
-- ---------------------------------------------------------------------
-- pg_dump / Backup enregistre la commande CREATE EXTENSION, pas le code
-- de l'extension. Le serveur qui restaure doit donc avoir les mêmes
-- extensions DISPONIBLES (même Bundle installé), sinon la restauration
-- échoue avec : could not open extension control file "…/h3.control".
