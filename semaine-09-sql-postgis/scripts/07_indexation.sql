-- =====================================================================
--  GEO7531 - Semaine 9 - 07 : L'indexation, pas à pas
--  Diapositives 169 à 188 de la présentation
-- =====================================================================


-- ---------------------------------------------------------------------
-- Diapo 171 : l'index B-tree, pour les attributs (texte, nombres, dates)
-- ---------------------------------------------------------------------
-- Créer un index B-tree (type par défaut)
CREATE INDEX nyc_neighborhoods_name_idx
  ON nyc_neighborhoods (name);

-- L'index sert pour =, <, >, BETWEEN et LIKE 'Lit%' (début de chaîne)
EXPLAIN
SELECT * FROM nyc_neighborhoods
WHERE name = 'Little Italy';


-- ---------------------------------------------------------------------
-- Diapo 173 : la boîte englobante (bounding box)
-- ---------------------------------------------------------------------
-- La boîte d'un quartier
SELECT name,
       ST_NPoints(geom) AS nb_sommets,
       Box2D(geom)      AS boite
FROM nyc_neighborhoods
WHERE name = 'West Village';
-- boite = BOX(xmin ymin, xmax ymax)

-- La même boîte, en polygone, pour l'afficher dans QGIS
SELECT ST_Envelope(geom)
FROM nyc_neighborhoods
WHERE name = 'West Village';


-- ---------------------------------------------------------------------
-- Diapo 174 : deux boîtes se touchent-elles ? L'opérateur &&
-- ---------------------------------------------------------------------
-- Cas de gauche : vrai
SELECT ST_MakeEnvelope(0, 0, 2, 2)
    && ST_MakeEnvelope(1, 1, 3, 3);

-- Cas de droite : faux
SELECT ST_MakeEnvelope(0, 0, 1, 1)
    && ST_MakeEnvelope(2, 1, 3, 2);

-- && compare les boîtes, jamais les formes exactes :
--   A.xmin <= B.xmax AND A.xmax >= B.xmin
--   AND A.ymin <= B.ymax AND A.ymax >= B.ymin


-- ---------------------------------------------------------------------
-- Diapo 177 : dans PostgreSQL, le R-tree s'appelle GiST
-- ---------------------------------------------------------------------
-- Créer l'index spatial
-- (s'il existe déjà, par exemple créé par shp2pgsql -I ou la restauration,
--  PostgreSQL répond « already exists » : vérifiez avec la requête suivante)
CREATE INDEX IF NOT EXISTS nyc_census_blocks_geom_idx
  ON nyc_census_blocks
  USING GIST (geom);

-- Quels index existent sur les tables nyc ?
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename LIKE 'nyc_%'
ORDER BY tablename;


-- ---------------------------------------------------------------------
-- Diapo 179 : le cas du West Village - pourquoi 49 821 ≠ 26 718
-- ---------------------------------------------------------------------
-- Étape 1 seule : boîtes
SELECT Sum(blk.popn_total)
FROM nyc_neighborhoods nh
JOIN nyc_census_blocks blk
  ON nh.geom && blk.geom
WHERE nh.name = 'West Village';
-- 49 821 (trop : faux positifs)

-- Étapes 1 + 2 : forme exacte
SELECT Sum(blk.popn_total)
FROM nyc_neighborhoods nh
JOIN nyc_census_blocks blk
  ON ST_Intersects(nh.geom, blk.geom)
WHERE nh.name = 'West Village';
-- 26 718


-- ---------------------------------------------------------------------
-- Diapo 181 : ST_DWithin, la recherche par rayon expliquée
-- ---------------------------------------------------------------------
-- Ce que vous écrivez
SELECT c.blkid
FROM nyc_census_blocks c
JOIN nyc_subway_stations s
  ON ST_DWithin(c.geom, s.geom, 500)
WHERE s.name = 'Broad St';

-- Ce que PostGIS fait (équivalent)
SELECT c.blkid
FROM nyc_census_blocks c
JOIN nyc_subway_stations s
  ON c.geom && ST_Expand(s.geom, 500)
 AND ST_Distance(c.geom, s.geom) <= 500
WHERE s.name = 'Broad St';


-- ---------------------------------------------------------------------
-- Diapo 182 : le piège classique - envelopper la colonne indexée
-- ---------------------------------------------------------------------
-- À ÉVITER : l'index sur geom est inutilisable,
-- la colonne est transformée ligne par ligne
SELECT count(*) FROM nyc_streets
WHERE ST_Intersects(
        ST_Transform(geom, 4326),
        'SRID=4326;LINESTRING(-74 40, -74 41)');

-- CORRECT : transformer la constante, une seule fois
SELECT count(*) FROM nyc_streets
WHERE ST_Intersects(geom,
        ST_Transform(ST_Segmentize(
          'SRID=4326;LINESTRING(-74 40, -74 41)'::geometry,
          0.01), 26918));

-- CORRECT : ou créer un index « fonctionnel »
CREATE INDEX nyc_streets_geom4326_idx
  ON nyc_streets USING GIST (ST_Transform(geom, 4326));


-- ---------------------------------------------------------------------
-- Diapo 183 : le plus proche voisin avec <->
-- ---------------------------------------------------------------------
-- Les 2 stations les plus proches de l'Empire State Building
SELECT name, routes,
       round(ST_Distance(geom, p.pt)::numeric) AS dist_m
FROM nyc_subway_stations,
     (SELECT ST_Transform(
               ST_SetSRID(
                 ST_MakePoint(-73.9857, 40.7484),
                 4326), 26918) AS pt) AS p
ORDER BY geom <-> p.pt
LIMIT 2;


-- ---------------------------------------------------------------------
-- Diapo 184 : lire un plan d'exécution - l'index est-il utilisé ?
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT count(*)
FROM nyc_census_blocks c
JOIN nyc_subway_stations s
  ON ST_DWithin(c.geom, s.geom, 500);
-- Bon signe : « Index Scan using …_geom_idx » et une ligne « Index Cond » avec &&
-- Mauvais signe : « Seq Scan » sur nyc_census_blocks


-- ---------------------------------------------------------------------
-- Diapo 185 : l'expérience avant / après, sans supprimer l'index
-- ---------------------------------------------------------------------
-- 1. Interdire l'index, pour cette session seulement
SET enable_indexscan  = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT b.blkid
FROM nyc_census_blocks b
JOIN nyc_subway_stations s
  ON ST_Contains(b.geom, s.geom)
WHERE s.name LIKE 'B%';
-- noter « Seq Scan » et l'Execution Time

-- 2. Rétablir le comportement normal
RESET enable_indexscan;
RESET enable_bitmapscan;
-- relancer le même EXPLAIN ANALYZE et comparer


-- ---------------------------------------------------------------------
-- Diapo 186 : VACUUM ANALYZE - une carte à jour pour le planificateur
-- (VACUUM ne s'exécute pas dans une transaction : lancez cette ligne seule)
-- ---------------------------------------------------------------------
VACUUM ANALYZE nyc_census_blocks;

-- Quand les statistiques ont-elles été calculées ?
SELECT relname,
       n_live_tup AS lignes,
       n_dead_tup AS lignes_mortes,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE relname LIKE 'nyc_%';


-- ---------------------------------------------------------------------
-- Diapo 187 : les types d'index de PostgreSQL (un exemple par type)
-- ---------------------------------------------------------------------
CREATE INDEX ON nyc_streets (name);                                        -- B-tree
CREATE INDEX ON nyc_census_blocks USING HASH (blkid);                      -- Hash
CREATE INDEX ON nyc_streets USING GIST (geom);                             -- GiST
CREATE INDEX ON nyc_homicides USING SPGIST (geom);                         -- SP-GiST
CREATE INDEX ON nyc_homicides USING BRIN (incident_d);                     -- BRIN
CREATE INDEX ON nyc_subway_stations USING GIN (string_to_array(routes, ',')); -- GIN
-- En pratique : B-tree pour les attributs, GiST pour les géométries.


-- ---------------------------------------------------------------------
-- Diapo 188 : ce que coûte un index
-- ---------------------------------------------------------------------
-- Taille de la table et de son index spatial
SELECT pg_size_pretty(pg_relation_size('nyc_census_blocks'))          AS table,
       pg_size_pretty(pg_relation_size('nyc_census_blocks_geom_idx')) AS index_gist,
       pg_size_pretty(pg_indexes_size('nyc_census_blocks'))           AS tous_les_index;
