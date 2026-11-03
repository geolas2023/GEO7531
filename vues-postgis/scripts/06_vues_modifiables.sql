-- =====================================================================
--  GEO7531 - Vues 06 : Écrire à travers une vue
--  Section 7 du tutoriel
--
--  Une vue SIMPLE (une seule table, sans GROUP BY, DISTINCT, agrégat,
--  LIMIT, UNION…) est modifiable automatiquement : INSERT, UPDATE et
--  DELETE sur la vue sont transmis à la table.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Une vue simple est modifiable
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_stations_manhattan AS
SELECT id, name, borough, routes, geom
FROM atelier.stations
WHERE borough = 'Manhattan';

-- Vérifier si une vue est modifiable
SELECT table_name, is_updatable, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'atelier'
ORDER BY table_name;
-- v_stations_manhattan : YES / YES
-- v_densite_quartiers  : NO  / NO   (GROUP BY)

-- Modifier à travers la vue : c'est la table qui change
UPDATE atelier.v_stations_manhattan
SET routes = routes || ',T'
WHERE name = 'Broad St';

SELECT name, routes FROM atelier.stations WHERE name = 'Broad St';

UPDATE atelier.v_stations_manhattan
SET routes = replace(routes, ',T', '')
WHERE name = 'Broad St';


-- ---------------------------------------------------------------------
-- 2. Le problème : écrire une ligne que la vue ne montre pas
-- ---------------------------------------------------------------------
INSERT INTO atelier.v_stations_manhattan (name, borough, routes, geom)
VALUES ('Station fantôme', 'Brooklyn', 'Q',
        ST_GeomFromText('POINT(587000 4505000)', 26918));
-- Accepté… mais la station est dans Brooklyn : elle n'apparaît pas
-- dans la vue qui vient de la créer.

SELECT count(*) FROM atelier.v_stations_manhattan WHERE name = 'Station fantôme';  -- 0
SELECT count(*) FROM atelier.stations             WHERE name = 'Station fantôme';  -- 1

DELETE FROM atelier.stations WHERE name = 'Station fantôme';


-- ---------------------------------------------------------------------
-- 3. La solution : WITH CHECK OPTION
--    Toute ligne écrite par la vue doit respecter son WHERE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_stations_manhattan AS
SELECT id, name, borough, routes, geom
FROM atelier.stations
WHERE borough = 'Manhattan'
WITH CHECK OPTION;

INSERT INTO atelier.v_stations_manhattan (name, borough, routes, geom)
VALUES ('Station fantôme', 'Brooklyn', 'Q',
        ST_GeomFromText('POINT(587000 4505000)', 26918));
-- ERREUR: new row violates check option for view "v_stations_manhattan"


-- ---------------------------------------------------------------------
-- 4. Une zone d'édition SPATIALE : seules les stations situées dans
--    le quartier Financial District peuvent être créées ou déplacées
--    à travers cette vue (pratique pour une couche d'édition dans QGIS)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_edition_financial_district AS
SELECT id, name, routes, geom
FROM atelier.stations AS s
WHERE ST_Within(s.geom, (SELECT q.geom FROM atelier.quartiers AS q
                         WHERE q.name = 'Financial District'))
WITH CHECK OPTION;

SELECT name FROM atelier.v_edition_financial_district;

-- Déplacer Broad St de 20 m : reste dans le quartier → accepté
UPDATE atelier.v_edition_financial_district
SET geom = ST_Translate(geom, 20, 0)
WHERE name = 'Broad St';

-- La déplacer de 3 km vers le nord : sort du quartier → refusé
UPDATE atelier.v_edition_financial_district
SET geom = ST_Translate(geom, 0, 3000)
WHERE name = 'Broad St';
-- ERREUR: new row violates check option for view "v_edition_financial_district"

-- Remettre Broad St à sa place
UPDATE atelier.stations SET geom = ST_Translate(geom, -20, 0) WHERE name = 'Broad St';


-- ---------------------------------------------------------------------
-- 5. Les colonnes calculées ne sont pas modifiables
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_stations_wgs84 AS
SELECT id, name, routes,
       ST_X(ST_Transform(geom, 4326)) AS lon,
       ST_Y(ST_Transform(geom, 4326)) AS lat
FROM atelier.stations;

UPDATE atelier.v_stations_wgs84 SET routes = routes WHERE name = 'Broad St';  -- accepté
UPDATE atelier.v_stations_wgs84 SET lon = -74.0 WHERE name = 'Broad St';      -- refusé
-- ERREUR: cannot update column "lon" of view "v_stations_wgs84"
-- DETAIL: View columns that are not columns of their base relation are not updatable.
--
-- Pour rendre ce genre de vue modifiable : un déclencheur INSTEAD OF
-- (tutoriel « Les déclencheurs », section 9).
