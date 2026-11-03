-- =====================================================================
--  GEO7531 - Vues 02 : Des vues spatiales prêtes pour QGIS
--  Section 3 du tutoriel
--
--  Pour qu'une vue s'affiche correctement dans QGIS, il lui faut :
--   1. une colonne identifiant UNIQUE (id) ;
--   2. une colonne géométrique de type et SRID connus.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Une jointure spatiale : chaque station avec son quartier
--    La géométrie vient telle quelle de la table : type connu (Point, 26918)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_stations_quartier AS
SELECT s.id,
       s.name,
       s.routes,
       q.name     AS quartier,
       q.boroname AS arrondissement,
       s.geom
FROM atelier.stations AS s
LEFT JOIN atelier.quartiers AS q
  ON ST_Contains(q.geom, s.geom);

SELECT * FROM atelier.v_stations_quartier WHERE name = 'Broad St';


-- ---------------------------------------------------------------------
-- B. Une carte choroplèthe : densité de population par quartier
--    GROUP BY q.id : la clé primaire suffit, PostgreSQL sait que les
--    autres colonnes de q (name, boroname, geom) en dépendent.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_densite_quartiers AS
SELECT q.id,
       q.name,
       q.boroname,
       sum(i.popn_total) AS population,
       round((sum(i.popn_total) / (ST_Area(q.geom) / 1e6))::numeric) AS hab_km2,
       q.geom
FROM atelier.quartiers AS q
JOIN atelier.ilots AS i
  ON ST_Contains(q.geom, ST_PointOnSurface(i.geom))   -- un îlot = un seul quartier
GROUP BY q.id;

SELECT name, boroname, population, hab_km2
FROM atelier.v_densite_quartiers
ORDER BY hab_km2 DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- C. Une géométrie CALCULÉE : zones de 500 m autour des stations
--    ST_Buffer renvoie un « geometry » sans type ni SRID déclarés.
--    Le transtypage ::geometry(Polygon, 26918) les annonce à QGIS.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_zones_500m AS
SELECT id,
       name,
       routes,
       ST_Buffer(geom, 500)::geometry(Polygon, 26918) AS geom
FROM atelier.stations;


-- ---------------------------------------------------------------------
-- D. Une géométrie AGRÉGÉE : les arrondissements par fusion des quartiers
--    Pas d'id dans la table de départ : row_number() en fabrique un.
--    (Calcul lourd, refait à chaque affichage : voir les vues
--     matérialisées, section 6.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW atelier.v_arrondissements AS
SELECT row_number() OVER (ORDER BY boroname) AS id,
       boroname,
       count(*) AS nb_quartiers,
       ST_Multi(ST_Union(geom))::geometry(MultiPolygon, 26918) AS geom
FROM atelier.quartiers
GROUP BY boroname;


-- ---------------------------------------------------------------------
-- Les vues spatiales sont inscrites dans geometry_columns, comme les tables
-- ---------------------------------------------------------------------
SELECT f_table_name, f_geometry_column, type, srid
FROM geometry_columns
WHERE f_table_schema = 'atelier'
ORDER BY f_table_name;
-- v_zones_500m : POLYGON, 26918 grâce au transtypage.
-- Sans lui, on lirait GEOMETRY, 0 et QGIS demanderait le type et le SRID.
