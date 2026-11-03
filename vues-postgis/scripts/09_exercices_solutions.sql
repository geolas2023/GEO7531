-- =====================================================================
--  GEO7531 - Vues 09 : Solutions des exercices
--  Section 11 du tutoriel. Essayez d'abord sans regarder !
-- =====================================================================


-- ---------------------------------------------------------------------
-- Exercice 1 : une couche des autoroutes pour QGIS
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_autoroutes AS
SELECT id, name, type, geom
FROM atelier.rues
WHERE type IN ('motorway', 'motorway_link');

SELECT count(*), round(sum(ST_Length(geom)) / 1000) AS km
FROM atelier.v_autoroutes;


-- ---------------------------------------------------------------------
-- Exercice 2 : chaque homicide avec son quartier et la station la plus proche
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_homicides_contexte AS
SELECT h.id,
       h.year,
       h.weapon,
       q.name AS quartier,
       s.name AS station_proche,
       round(ST_Distance(h.geom, s.geom)) AS dist_station_m,
       h.geom
FROM atelier.homicides AS h
LEFT JOIN atelier.quartiers AS q
  ON ST_Contains(q.geom, h.geom)
CROSS JOIN LATERAL (
  SELECT name, geom FROM atelier.stations
  ORDER BY geom <-> h.geom
  LIMIT 1
) AS s;

SELECT * FROM atelier.v_homicides_contexte WHERE year = 2010 LIMIT 5;


-- ---------------------------------------------------------------------
-- Exercice 3 : longueur de rues par arrondissement, matérialisée
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW atelier.mv_longueur_rues AS
SELECT a.id,
       a.boroname,
       round(sum(ST_Length(ST_Intersection(r.geom, a.geom))) / 1000) AS km_rues,
       a.geom
FROM atelier.mv_arrondissements AS a
JOIN atelier.rues AS r ON ST_Intersects(r.geom, a.geom)
GROUP BY a.id, a.boroname, a.geom;

CREATE UNIQUE INDEX ON atelier.mv_longueur_rues (id);
CREATE INDEX ON atelier.mv_longueur_rues USING GIST (geom);

SELECT boroname, km_rues FROM atelier.mv_longueur_rues ORDER BY km_rues DESC;


-- ---------------------------------------------------------------------
-- Exercice 4 : une vue d'édition limitée aux rues à sens unique
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_edition_sens_unique AS
SELECT id, name, oneway, geom
FROM atelier.rues
WHERE oneway = 'yes'
WITH CHECK OPTION;

-- Accepté : on renomme une rue à sens unique
UPDATE atelier.v_edition_sens_unique
SET name = name || ' (vérifié)'
WHERE id = (SELECT min(id) FROM atelier.v_edition_sens_unique);

-- Refusé : la rue sortirait de la vue
UPDATE atelier.v_edition_sens_unique
SET oneway = 'no'
WHERE id = (SELECT min(id) FROM atelier.v_edition_sens_unique);
-- ERREUR: new row violates check option for view "v_edition_sens_unique"

-- Remettre le nom d'origine
UPDATE atelier.rues SET name = replace(name, ' (vérifié)', '')
WHERE name LIKE '% (vérifié)';
