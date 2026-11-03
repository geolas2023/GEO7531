-- =====================================================================
--  GEO7531 - Extensions 03 : Un test court par extension
--  À exécuter dans la base qui contient les données NYC
--  (restaurées avec le tutoriel « Créer, restaurer et sauvegarder »).
--  SRID des données NYC : 26918 (NAD83 / UTM zone 18N, en mètres).
--
--  Exécutez les blocs un par un (sélection + F5). Les tests qui créent
--  des objets les suppriment à la fin du bloc.
-- =====================================================================


-- ---------------------------------------------------------------------
-- postgis : la station Broad St en WGS 84
-- ---------------------------------------------------------------------
SELECT name, ST_AsText(ST_Transform(geom, 4326)) AS wgs84
FROM nyc_subway_stations
WHERE name = 'Broad St';


-- ---------------------------------------------------------------------
-- postgis_raster : rastériser un quartier en pixels de 50 m
-- ---------------------------------------------------------------------
SELECT name,
       ST_Width(r)  AS colonnes,
       ST_Height(r) AS lignes,
       (ST_SummaryStats(r)).count AS pixels_dans_le_quartier
FROM (
  SELECT name, ST_AsRaster(geom, 50.0, -50.0, '8BUI', 1, 0) AS r
  FROM nyc_neighborhoods
  WHERE name = 'West Village'
) AS t;


-- ---------------------------------------------------------------------
-- postgis_topology : deux carrés qui partagent un côté
-- L'arête commune n'est stockée qu'une seule fois.
-- ---------------------------------------------------------------------
SELECT topology.CreateTopology('topo_demo');
SELECT topology.ST_CreateTopoGeo('topo_demo',
  'GEOMETRYCOLLECTION(POLYGON((0 0,10 0,10 10,0 10,0 0)),
                      POLYGON((10 0,20 0,20 10,10 10,10 0)))');
SELECT 'noeuds' AS element, count(*) FROM topo_demo.node
UNION ALL SELECT 'aretes', count(*) FROM topo_demo.edge
UNION ALL SELECT 'faces (sans la face universelle 0)', count(*) FROM topo_demo.face WHERE face_id > 0;
SELECT topology.DropTopology('topo_demo');


-- ---------------------------------------------------------------------
-- postgis_sfcgal : extruder une emprise de 100 m x 50 m sur 30 m de haut
-- PostGIS 3.5 et plus : fonctions CG_* ; avant : ST_Extrude, ST_Volume…
-- ---------------------------------------------------------------------
SELECT postgis_sfcgal_version();
SELECT CG_Volume(CG_MakeSolid(
         CG_Extrude(ST_MakeEnvelope(0, 0, 100, 50, 26918), 0, 0, 30)
       )) AS volume_m3;   -- 150 000


-- ---------------------------------------------------------------------
-- fuzzystrmatch : retrouver un quartier malgré une faute de frappe
-- ---------------------------------------------------------------------
SELECT name, levenshtein(name, 'Grenwich Vilage') AS nb_modifications
FROM nyc_neighborhoods
ORDER BY nb_modifications
LIMIT 3;


-- ---------------------------------------------------------------------
-- pg_trgm : similarité (0 à 1) et index pour accélérer la recherche
-- ---------------------------------------------------------------------
SELECT name, round(similarity(name, 'washington hights')::numeric, 2) AS sim
FROM nyc_neighborhoods
WHERE name % 'washington hights'      -- % = « assez semblable »
ORDER BY sim DESC;

CREATE INDEX IF NOT EXISTS nyc_streets_name_trgm_idx
  ON nyc_streets USING GIN (name gin_trgm_ops);   -- accélère aussi LIKE '%Ave%'


-- ---------------------------------------------------------------------
-- unaccent : comparer des toponymes sans tenir compte des accents
-- ---------------------------------------------------------------------
SELECT unaccent('Montréal, Trois-Rivières, Québec') AS sans_accents;
SELECT unaccent(lower('Île-Bizard')) = unaccent(lower('ile-bizard')) AS identiques;


-- ---------------------------------------------------------------------
-- address_standardizer : découper une adresse américaine
-- ---------------------------------------------------------------------
SELECT house_num, name, suftype, city, state, postcode
FROM standardize_address('us_lex', 'us_gaz', 'us_rules',
                         '350 Fifth Avenue', 'New York, NY 10118');


-- ---------------------------------------------------------------------
-- postgis_tiger_geocoder : normaliser une adresse (sans données TIGER)
-- ---------------------------------------------------------------------
-- Les fonctions sont dans le schéma tiger, d'où le préfixe.
SELECT tiger.pprint_addy(tiger.normalize_address('350 fifth avenue, new york, ny 10118'));


-- ---------------------------------------------------------------------
-- pgrouting : version (l'exemple complet est dans le script 04)
-- ---------------------------------------------------------------------
SELECT pgr_version();


-- ---------------------------------------------------------------------
-- pointcloud : version (importation LiDAR : tutoriel « Importer », section 9)
-- ---------------------------------------------------------------------
SELECT PC_Version();


-- ---------------------------------------------------------------------
-- ogr_fdw : lire un shapefile sans l'importer
-- Adaptez le chemin : dossier qui contient les .shp de NYC.
-- Le dossier doit être lisible par le SERVICE PostgreSQL (évitez OneDrive).
-- ---------------------------------------------------------------------
CREATE SERVER IF NOT EXISTS shp_nyc
  FOREIGN DATA WRAPPER ogr_fdw
  OPTIONS (datasource 'C:/GEO7531/data', format 'ESRI Shapefile');

CREATE SCHEMA IF NOT EXISTS externe;
IMPORT FOREIGN SCHEMA ogr_all FROM SERVER shp_nyc INTO externe;

-- Les shapefiles apparaissent comme des tables du schéma externe :
SELECT foreign_table_name FROM information_schema.foreign_tables
WHERE foreign_table_schema = 'externe';

-- Exemple (le nom exact dépend du fichier) :
-- SELECT count(*) FROM externe.nyc_homicides;

-- Nettoyage :
-- DROP SCHEMA externe CASCADE;  DROP SERVER shp_nyc CASCADE;


-- ---------------------------------------------------------------------
-- h3 + h3_postgis : compter les homicides par hexagone (résolution 8)
-- H3 travaille en latitude/longitude : ST_Transform(…, 4326) obligatoire.
-- ---------------------------------------------------------------------
SELECT h3_lat_lng_to_cell(POINT(-73.9857, 40.7484), 9) AS cellule_empire_state;

CREATE TABLE IF NOT EXISTS homicides_h3 AS
SELECT cellule,
       count(*) AS nb_homicides,
       h3_cell_to_boundary_geometry(cellule) AS geom   -- hexagone en 4326
FROM (
  SELECT h3_lat_lng_to_cell(ST_Transform(geom, 4326), 8) AS cellule
  FROM nyc_homicides
) AS t
GROUP BY cellule;

SELECT * FROM homicides_h3 ORDER BY nb_homicides DESC LIMIT 5;
-- Ajoutez homicides_h3 dans QGIS pour une carte choroplèthe en hexagones.
-- DROP TABLE homicides_h3;


-- ---------------------------------------------------------------------
-- hstore : des étiquettes clé=valeur, comme dans OpenStreetMap
-- ---------------------------------------------------------------------
SELECT etiquettes -> 'amenity' AS type, etiquettes -> 'name' AS nom
FROM (SELECT 'amenity=>library, name=>"Bibliothèque des sciences"'::hstore AS etiquettes) AS t;


-- ---------------------------------------------------------------------
-- btree_gist : un seul index pour un attribut ET une géométrie
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS nyc_census_blocks_boro_geom_idx
  ON nyc_census_blocks USING GIST (boroname, geom);
-- Sert aux requêtes du type :
-- WHERE boroname = 'Manhattan' AND ST_Intersects(geom, …)
