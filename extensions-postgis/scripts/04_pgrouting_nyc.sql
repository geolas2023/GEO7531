-- =====================================================================
--  GEO7531 - Extensions 04 : Premier itinéraire avec pgRouting (rues NYC)
--  À exécuter dans la base qui contient nyc_streets et nyc_subway_stations.
--  Prérequis : CREATE EXTENSION pgrouting;  (script 02)
--
--  Compatible pgRouting 3.x et 4.x : on construit la topologie avec
--  pgr_extractVertices. L'ancienne fonction pgr_createTopology est
--  dépréciée depuis 3.8 et retirée de pgRouting 4.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Une table d'arêtes : une ligne simple (LineString) par tronçon
--    nyc_streets contient des MultiLineString : ST_Dump les sépare.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS reseau, reseau_noeuds, itineraire, zone_500m;

CREATE TABLE reseau AS
SELECT row_number() OVER ()::bigint AS id,
       name, type,
       geom::geometry(LineString, 26918) AS geom
FROM (
  SELECT name, type, (ST_Dump(geom)).geom AS geom
  FROM nyc_streets
) AS d;

ALTER TABLE reseau ADD PRIMARY KEY (id);
ALTER TABLE reseau ADD COLUMN source bigint,
                   ADD COLUMN target bigint,
                   ADD COLUMN cost   float8;

-- Coût = longueur en mètres (on pourrait diviser par une vitesse pour des minutes)
UPDATE reseau SET cost = ST_Length(geom);


-- ---------------------------------------------------------------------
-- 2. Les nœuds : extrémités des tronçons
-- ---------------------------------------------------------------------
SELECT * INTO reseau_noeuds
FROM pgr_extractVertices('SELECT id, geom FROM reseau ORDER BY id');

CREATE INDEX reseau_noeuds_geom_idx ON reseau_noeuds USING GIST (geom);

-- Chaque tronçon reçoit son nœud de départ (source) et d'arrivée (target)
UPDATE reseau AS e SET source = v.id
FROM (SELECT id, unnest(out_edges) AS e_id FROM reseau_noeuds) AS v
WHERE e.id = v.e_id;

UPDATE reseau AS e SET target = v.id
FROM (SELECT id, unnest(in_edges) AS e_id FROM reseau_noeuds) AS v
WHERE e.id = v.e_id;

-- Contrôle : aucun tronçon ne doit rester sans source ou target
SELECT count(*) AS troncons_incomplets
FROM reseau WHERE source IS NULL OR target IS NULL;


-- ---------------------------------------------------------------------
-- 3. Le plus court chemin entre deux stations (algorithme de Dijkstra)
--    On part du nœud du réseau le plus proche de chaque station (<->).
--    directed := false : on marche, le sens unique ne compte pas.
-- ---------------------------------------------------------------------
CREATE TABLE itineraire AS
WITH depart AS (
  SELECT v.id FROM reseau_noeuds v, nyc_subway_stations s
  WHERE s.name = 'Broad St'
  ORDER BY v.geom <-> s.geom LIMIT 1
), arrivee AS (
  SELECT v.id FROM reseau_noeuds v, nyc_subway_stations s
  WHERE s.name = 'Whitehall St'
  ORDER BY v.geom <-> s.geom LIMIT 1
)
SELECT d.seq, r.id, r.name, round(r.cost::numeric, 1) AS metres, r.geom
FROM pgr_dijkstra(
       'SELECT id, source, target, cost, cost AS reverse_cost FROM reseau',
       (SELECT id FROM depart),
       (SELECT id FROM arrivee),
       directed := false) AS d
JOIN reseau AS r ON r.id = d.edge
ORDER BY d.seq;

SELECT * FROM itineraire;
SELECT round(sum(metres)) AS longueur_totale_m FROM itineraire;
-- Ajoutez la table itineraire dans QGIS pour voir le trajet.


-- ---------------------------------------------------------------------
-- 4. Zone accessible à pied : tout ce qui est à moins de 500 m de réseau
--    de la station Broad St (et non 500 m à vol d'oiseau)
-- ---------------------------------------------------------------------
CREATE TABLE zone_500m AS
SELECT 1 AS id,
       ST_ConcaveHull(ST_Collect(v.geom), 0.3) AS geom
FROM pgr_drivingDistance(
       'SELECT id, source, target, cost, cost AS reverse_cost FROM reseau',
       (SELECT v.id FROM reseau_noeuds v, nyc_subway_stations s
        WHERE s.name = 'Broad St'
        ORDER BY v.geom <-> s.geom LIMIT 1),
       500,
       directed := false) AS dd
JOIN reseau_noeuds AS v ON v.id = dd.node;

SELECT round(ST_Area(geom)) AS surface_m2 FROM zone_500m;
-- À comparer, dans QGIS, avec ST_Buffer(station, 500) : le réseau réel
-- donne une zone plus petite et moins régulière qu'un cercle.


-- ---------------------------------------------------------------------
-- Si pgr_dijkstra ne renvoie aucune ligne
-- ---------------------------------------------------------------------
-- Les rues ne sont reliées que si elles se touchent EXACTEMENT à leurs
-- extrémités. Si deux rues se croisent sans être coupées à l'intersection,
-- le réseau est « troué ». Vérifiez le nombre de composantes connexes :
--
-- SELECT component, count(*) AS nb_noeuds
-- FROM pgr_connectedComponents(
--   'SELECT id, source, target, cost, cost AS reverse_cost FROM reseau')
-- GROUP BY component ORDER BY nb_noeuds DESC LIMIT 5;
--
-- Une très grande composante + beaucoup de petites = réseau à nettoyer
-- (couper aux intersections avec ST_Node, ou corriger dans QGIS).
