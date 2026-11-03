# GEO7531 — Semaine 9 : toutes les requêtes SQL de la présentation « Introduction à PostgreSQL et PostGIS »

Ce tutoriel rassemble, dans l'ordre de la présentation, **tout le code SQL** du cours de la semaine 9 : création de la base, SQL simple, géométries, relations spatiales, jointures spatiales, projections et indexation. Chaque requête est précédée du numéro de la diapositive et de la question à laquelle elle répond, et suivie, en commentaire, du résultat affiché dans la présentation.

> **Pour qui ?** Étudiant·e·s qui veulent refaire les exemples du cours sans recopier le code des diapositives.
> **Prérequis :** la base `nyc` avec les données NYC restaurées (voir le tutoriel [Créer, restaurer et sauvegarder une base](../README.md)).

---

## Table des matières

0. [Comment utiliser ce tutoriel](#0-comment-utiliser-ce-tutoriel)
1. [Créer la base de données spatiale](#1-créer-la-base-de-données-spatiale) — Sections 4 et 5 · diapositives 14 à 33
2. [SQL simple](#2-sql-simple) — Sections 7 et 8 · diapositives 40 à 56
3. [Géométries](#3-géométries) — Sections 9 et 10 · diapositives 57 à 96
4. [Relations spatiales](#4-relations-spatiales) — Sections 11 et 12 · diapositives 97 à 127
5. [Jointures spatiales](#5-jointures-spatiales) — Sections 13 et 14 · diapositives 128 à 152
6. [Projection des données](#6-projection-des-données) — Sections 16 et 17 · diapositives 153 à 168
7. [L'indexation, pas à pas](#7-lindexation-pas-à-pas) — Diapositives 169 à 188
8. [Problèmes fréquents](#8-problèmes-fréquents)

Fichiers du dossier [`scripts/`](scripts/) :

| Fichier | Contenu |
|---|---|
| [`01_creer_base.sql`](scripts/01_creer_base.sql) | Créer la base de données spatiale (sections 4 et 5 · diapositives 14 à 33) |
| [`02_sql_simple.sql`](scripts/02_sql_simple.sql) | SQL simple (sections 7 et 8 · diapositives 40 à 56) |
| [`03_geometries.sql`](scripts/03_geometries.sql) | Géométries (sections 9 et 10 · diapositives 57 à 96) |
| [`04_relations_spatiales.sql`](scripts/04_relations_spatiales.sql) | Relations spatiales (sections 11 et 12 · diapositives 97 à 127) |
| [`05_jointures_spatiales.sql`](scripts/05_jointures_spatiales.sql) | Jointures spatiales (sections 13 et 14 · diapositives 128 à 152) |
| [`06_projections.sql`](scripts/06_projections.sql) | Projection des données (sections 16 et 17 · diapositives 153 à 168) |
| [`07_indexation.sql`](scripts/07_indexation.sql) | L'indexation, pas à pas (diapositives 169 à 188) |
| [`00_charger_shapefile.bat`](scripts/00_charger_shapefile.bat) | Charger `nyc_census_blocks_2000.shp` avec shp2pgsql (Windows) — diapos 30 et 33 |
| [`00_charger_shapefile.sh`](scripts/00_charger_shapefile.sh) | Même chose avec ogr2ogr ou shp2pgsql (macOS / Linux) |

---

## 0. Comment utiliser ce tutoriel

1. Dans pgAdmin, faites un clic droit sur la base **`nyc`** → **Query Tool**.
2. Copiez une requête de cette page (ou ouvrez un fichier du dossier `scripts/` avec l'icône de dossier du Query Tool).
3. **Sélectionnez seulement la requête à exécuter**, puis appuyez sur **F5**. Sans sélection, pgAdmin exécute tout l'éditeur et n'affiche que le dernier résultat.
4. Pour voir une géométrie sur une carte, cliquez sur l'icône 👁 de la colonne géométrique dans le résultat (*Geometry Viewer*). Un fond de carte n'apparaît que si la géométrie est en EPSG:4326 : enveloppez-la dans `ST_Transform(geom, 4326)`.

> 💡 **Le nom de votre base.** La présentation utilise une base nommée `nyc`. Si vous avez restauré les données dans une base `GEO7531` (premier tutoriel), ouvrez simplement le Query Tool sur celle-ci : les requêtes sont identiques.

> ℹ️ Les lignes qui commencent par `--` sont des **commentaires** : PostgreSQL les ignore. Les résultats attendus y sont indiqués.

Rappel sur les données (section 6, diapos 34 à 39) :

| Table | Géométrie | Principales colonnes |
|---|---|---|
| `nyc_census_blocks` | MultiPolygon | `blkid`, `popn_total`, `popn_white`, `popn_black`, `popn_nativ`, `popn_asian`, `popn_other`, `boroname` |
| `nyc_neighborhoods` | MultiPolygon | `name`, `boroname` |
| `nyc_streets` | MultiLineString | `name`, `oneway`, `type` |
| `nyc_subway_stations` | Point | `name`, `borough`, `routes`, `transfers`, `express` |
| `nyc_census_sociodata` | aucune | `tractid`, `transit_*`, `family_*`, `edu_*` |

Toutes les géométries sont en **EPSG:26918** (NAD83 / UTM zone 18N) : les distances, longueurs et surfaces sont en **mètres**.

---

## 1. Créer la base de données spatiale

*Sections 4 et 5 · diapositives 14 à 33 — script : [`scripts/01_creer_base.sql`](scripts/01_creer_base.sql)*

**Diapo 28** — La base nyc (onglet SQL de pgAdmin)

À exécuter depuis la base « postgres », pas depuis la base nyc.

```sql
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
```

**Diapo 20** — Activer PostGIS dans la base nyc

```sql
CREATE EXTENSION postgis;
```

**Diapo 21** — Vérifier l'installation

```sql
SELECT postgis_full_version();
```

**Diapo 22** — Les extensions essentielles

```sql
-- IF NOT EXISTS : pas d'erreur si l'extension est déjà active
-- (postgis l'est depuis la diapo 20).
CREATE EXTENSION IF NOT EXISTS postgis;            -- géométries et fonctions spatiales
CREATE EXTENSION IF NOT EXISTS postgis_raster;     -- rasters : MNT, NDVI, images
CREATE EXTENSION IF NOT EXISTS postgis_topology;   -- modèle topologique : nœuds, arêtes, faces
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;      -- comparaison de chaînes (Levenshtein, Soundex)

-- Extensions installées dans la base :
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

**Diapos 25 à 28** — Restaurer nyc_data.backup

Se fait dans pgAdmin (clic droit sur la base nyc → **Restore...**). Voir le tutoriel [Créer, restaurer et sauvegarder une base](../README.md).

```sql
-- Vérification après la restauration :
SELECT f_table_name, f_geometry_column, type, srid
FROM geometry_columns;
```

**Diapos 29 à 33** — Charger un shapefile (ogr2ogr, shp2pgsql)

Les commandes de chargement des diapos 30 et 33 (`ogr2ogr`, `shp2pgsql`) ne sont pas du SQL : elles se tapent dans l'**invite de commandes** (Windows) ou un **terminal** (macOS / Linux), pas dans le Query Tool. Elles sont dans [`00_charger_shapefile.bat`](scripts/00_charger_shapefile.bat) et [`00_charger_shapefile.sh`](scripts/00_charger_shapefile.sh) :

```bash
# Diapo 30 — ogr2ogr
ogr2ogr \
  -nln nyc_census_blocks_2000 \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -lco FID=gid \
  -lco PRECISION=NO \
  Pg:'dbname=nyc host=localhost user=postgres port=5432' \
  nyc_census_blocks_2000.shp

# Diapo 33 — shp2pgsql
shp2pgsql \
  -D \
  -I \
  -s 26918 \
  nyc_census_blocks_2000.shp \
  nyc_census_blocks_2000 \
  | psql dbname=nyc user=postgres host=localhost
```

> ⚠️ Sous Windows (`cmd`), le caractère de suite de ligne est `^` et non `\`. Le plus simple est d'écrire la commande sur une seule ligne, comme dans le fichier `.bat`.

---

## 2. SQL simple

*Sections 7 et 8 · diapositives 40 à 56 — script : [`scripts/02_sql_simple.sql`](scripts/02_sql_simple.sql)*

### Section 7 - SQL simple

**Diapo 41** — Le nom de tous les quartiers

```sql
SELECT name
FROM nyc_neighborhoods;
```

**Diapos 42-43** — Afficher les quartiers sur la carte de pgAdmin

```sql
-- (onglet Geometry Viewer). Les données sont en UTM 18N (SRID 26918) :
-- ST_Transform les convertit en latitude/longitude (SRID 4326) pour que
-- pgAdmin puisse placer un fond de carte dessous.
SELECT name,
       ST_Transform(geom, 4326)
FROM nyc_neighborhoods;

SELECT geom,
       ST_Transform(geom, 4326)
FROM nyc_neighborhoods;
```

**Diapo 46** — Quels sont les noms de tous les quartiers de Brooklyn ?

```sql
SELECT name
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';
```

**Diapo 47** — Le nombre de lettres dans les noms des quartiers de Brooklyn

```sql
SELECT char_length(name)
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';
```

**Diapo 48** — Nombre moyen de lettres et écart-type, à Brooklyn

```sql
SELECT avg(char_length(name)),
       stddev(char_length(name))
FROM nyc_neighborhoods
WHERE boroname = 'Brooklyn';
```

**Diapo 49** — Nombre moyen de lettres, par arrondissement

```sql
SELECT boroname,
       avg(char_length(name))
FROM nyc_neighborhoods
GROUP BY boroname;
```

### Section 8 - Exercices SQL simples

**Diapo 51** — Combien d'enregistrements contient la table nyc_streets ?

```sql
SELECT Count(*)
FROM nyc_streets;
```

**Diapo 52** — Combien de rues de New York commencent par un « B » ?

```sql
SELECT Count(*)
FROM nyc_streets
WHERE name LIKE 'B%';
```

**Diapo 53** — Quelle est la population de New York ?

```sql
SELECT Sum(popn_total) AS population
FROM nyc_census_blocks;
```

**Diapo 54** — Quelle est la population du Bronx ?

```sql
SELECT Sum(popn_total)
FROM nyc_census_blocks
WHERE boroname = 'The Bronx';
```

**Diapo 55** — Combien y a-t-il de quartiers dans chaque arrondissement ?

```sql
SELECT boroname, Count(*)
FROM nyc_neighborhoods
GROUP BY boroname;
```

**Diapo 56** — Pourcentage de la population « blanche » par arrondissement

```sql
SELECT boroname,
       100.0 * Sum(popn_white) / Sum(popn_total) AS pct
FROM nyc_census_blocks
GROUP BY boroname;
```

---

## 3. Géométries

*Sections 9 et 10 · diapositives 57 à 96 — script : [`scripts/03_geometries.sql`](scripts/03_geometries.sql)*

### Section 9 - Géométries

**Diapo 59** — Créer une table avec une colonne géométrique

```sql
CREATE TABLE geometries (
  name varchar,
  geom geometry
);
```

**Diapo 60** — Insérer plusieurs types de géométries

```sql
INSERT INTO geometries (name, geom) VALUES
  ('Point', ST_GeomFromText('POINT(0 0)')),
  ('Linestring', ST_GeomFromText('LINESTRING(0 0, 1 1, 2 1, 2 2)')),
  ('Polygon', ST_GeomFromText('POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))')),
  ('PolygonWithHole', ST_GeomFromText('POLYGON((0 0, 3 0, 3 3, 0 3, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))')),
  ('Collection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(0 0), LINESTRING(0 0, 1 1, 2 2))'));
--  Voir aussi : http://postgis.net/workshops/postgis-intro/geometries.html
```

**Diapo 61** — Afficher les géométries sous forme de texte (WKT)

```sql
SELECT name, ST_AsText(geom)
FROM geometries;
```

**Diapo 63** — La vue geometry_columns

```sql
SELECT *
FROM geometry_columns;
```

**Diapo 65** — Fonctions de métadonnées

```sql
SELECT name,
       ST_GeometryType(geom),
       ST_NDims(geom),
       ST_SRID(geom)
FROM geometries;

-- ----- Points --------------------------------------------------------
```

**Diapo 68**

```sql
SELECT ST_AsText(geom)
FROM geometries
WHERE name = 'Point';
-- POINT(0 0)
```

**Diapo 69**

```sql
SELECT ST_X(geom),
       ST_Y(geom)
FROM geometries
WHERE name = 'Point';
-- 0 | 0
```

**Diapo 70**

```sql
SELECT name,
       ST_AsText(geom)
FROM nyc_subway_stations
LIMIT 1;
-- Cortlandt St | POINT(583521 4507077)

-- ----- Lignes (LineString) -------------------------------------------
```

**Diapo 72**

```sql
SELECT ST_AsText(geom)
FROM geometries
WHERE name = 'Linestring';
-- LINESTRING(0 0,1 1,2 1,2 2)
```

**Diapo 73**

```sql
SELECT ST_Length(geom)
FROM geometries
WHERE name = 'Linestring';
-- 3.41421356237309
```

**Diapo 74** — Autres fonctions sur les lignes

```sql
SELECT ST_Length(geom),
       ST_AsText(ST_StartPoint(geom)),
       ST_AsText(ST_EndPoint(geom)),
       ST_NumPoints(geom)
FROM geometries
WHERE name = 'Linestring';

-- ----- Polygones -----------------------------------------------------
```

**Diapo 77**

```sql
SELECT ST_AsText(geom)
FROM geometries
WHERE name LIKE 'Polygon%';
-- Polygon         : POLYGON((0 0,1 0,1 1,0 1,0 0))
-- PolygonWithHole : POLYGON((0 0,3 0,3 3,0 3,0 0),(1 1,2 1,2 2,1 2,1 1))
```

**Diapo 78** — Autres fonctions sur les polygones

```sql
SELECT name,
       ST_Area(geom),
       ST_NumInteriorRings(geom),
       ST_AsText(ST_ExteriorRing(geom)),
       ST_AsText(ST_InteriorRingN(geom, 1)),   -- 1er anneau intérieur (NULL s'il n'y en a pas)
       ST_Perimeter(geom)
FROM geometries
WHERE name LIKE 'Polygon%';
```

**Diapo 80**

```sql
SELECT name, ST_Area(geom)
FROM geometries
WHERE name LIKE 'Polygon%';
-- Polygon         | 1
-- PolygonWithHole | 8    (carré de 3 × 3 = 9, moins le trou de 1)

-- ----- Formats de géométrie (diapos 81 à 83) -------------------------
```

**Diapo 82** — Lire du WKT 3D, l'afficher en WKT

```sql
SELECT ST_AsText(
         ST_GeometryFromText('LINESTRING(0 0 0,1 0 0,1 1 2)')
       );
-- LINESTRING Z (0 0 0,1 0 0,1 1 2)
```

**Diapo 83** — Lire du GML, l'afficher en GeoJSON

```sql
SELECT ST_AsGeoJSON(
         ST_GeomFromGML('<gml:Point><gml:coordinates>1,1</gml:coordinates></gml:Point>')
       );
-- {"type":"Point","coordinates":[1,1]}

-- ----- Construire une géométrie avec un SRID (diapos 84 à 89) --------
-- Six façons d'obtenir le même résultat : SRID=4326;POINT(1 1)
```

**Diapo 84**

```sql
SELECT ST_AsEWKT(ST_GeomFromText('POINT(1 1)', 4326));
```

**Diapo 85**

```sql
SELECT ST_AsEWKT(ST_SetSRID(ST_GeomFromText('POINT(1 1)'), 4326));
```

**Diapo 86**

```sql
SELECT ST_AsEWKT(ST_SetSRID(ST_MakePoint(1, 1), 4326));
```

**Diapo 87**

```sql
SELECT ST_AsEWKT(ST_SetSRID('POINT(1 1)'::geometry, 4326));
```

**Diapo 88**

```sql
SELECT ST_AsEWKT('SRID=4326;POINT(1 1)'::geometry);
```

**Diapo 89** — (ST_Point avec SRID : PostGIS 3.2 et plus)

```sql
SELECT ST_AsEWKT(ST_Point(1, 1, 4326));
```

### Section 10 - Exercices de géométrie

**Diapo 91** — Superficie du quartier « West Village »

```sql
SELECT ST_Area(geom)
FROM nyc_neighborhoods
WHERE name = 'West Village';
-- 1044614.5296486   (m², car le SRID 26918 est en mètres)
```

**Diapo 92** — Type de géométrie et longueur de « Pelham St »

```sql
SELECT ST_GeometryType(geom),
       ST_Length(geom)
FROM nyc_streets
WHERE name = 'Pelham St';
-- ST_MultiLineString | 50.323
```

**Diapo 93** — Représentation GeoJSON de la station « Broad St »

```sql
SELECT ST_AsGeoJSON(geom, 0)
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- {"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:26918"}},
--  "coordinates":[583571,4506714]}
-- (Selon la version de PostGIS, la partie "crs" peut ne pas apparaître.)
```

**Diapo 94** — Longueur totale des rues de New York, en kilomètres

```sql
SELECT Sum(ST_Length(geom)) / 1000
FROM nyc_streets;
-- 10418.904717199996
```

**Diapo 95** — Superficie de Manhattan en acres (1 acre = 4047 m²)

```sql
SELECT Sum(ST_Area(geom)) / 4047
FROM nyc_census_blocks
WHERE boroname = 'Manhattan';
-- 14601.3987215548
```

**Diapo 96** — La station de métro la plus à l'ouest

```sql
SELECT ST_X(geom), name
FROM nyc_subway_stations
ORDER BY ST_X(geom)
LIMIT 1;
-- 563292.1 | Tottenville
```

---

## 4. Relations spatiales

*Sections 11 et 12 · diapositives 97 à 127 — script : [`scripts/04_relations_spatiales.sql`](scripts/04_relations_spatiales.sql)*

### Section 11 - Relations spatiales

**Diapo 105** — Quelle est la géométrie de la station Broad St ?

```sql
SELECT name, geom
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- 0101000020266900000EEBD4CF27CF2141BC17D69516315141   (format EWKB hexadécimal)
```

**Diapo 106** — Quelle station correspond à cette géométrie ? (ST_Equals)

```sql
SELECT name
FROM nyc_subway_stations
WHERE ST_Equals(
        geom,
        '0101000020266900000EEBD4CF27CF2141BC17D69516315141');
-- Broad St
```

**Diapo 108** — Le texte connu (WKT) de la station Broad St

```sql
SELECT name, ST_AsText(geom, 0)
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- POINT(583571 4506714)
```

**Diapo 109** — Quel quartier croise cette station ? (ST_Intersects)

```sql
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918));
-- Financial District | Manhattan
```

**Diapo 115** — ST_Distance entre un point et une ligne

```sql
SELECT ST_Distance(
         ST_GeomFromText('POINT(0 5)'),
         ST_GeomFromText('LINESTRING(-2 2, 2 2)')
       );
-- 3
```

**Diapo 117** — Les rues à moins de 10 m de la station Broad St (ST_DWithin)

```sql
SELECT name, geom
FROM nyc_streets
WHERE ST_DWithin(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918),
        10
      );
-- Wall St, Broad St, Nassau St (carte de la diapo 118)
```

### Section 12 - Exercices sur les relations spatiales

**Diapo 120** — Le texte connu de la rue « Atlantic Commons »

```sql
SELECT ST_AsText(geom, 0)
FROM nyc_streets
WHERE name = 'Atlantic Commons';
-- MULTILINESTRING((586782 4504202,586864 4504216))
```

**Diapo 121** — Dans quel quartier et quel arrondissement se trouve

```sql
-- POINT(586782 4504202) ?
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(586782 4504202)', 26918));
```

**Diapo 122** — Combien de personnes vivent à moins de 50 m de

```sql
-- POINT(586782 4504202) ?
SELECT Sum(popn_total)
FROM nyc_census_blocks
WHERE ST_DWithin(
        ST_SetSRID(geom, 26918),
        ST_GeomFromText('POINT(586782 4504202)', 26918),
        50
      );
```

**Diapos 123 à 125** — Pour LINESTRING(0 0, 2 2) et POINT(1 1), quelles relations sont vraies ?

```sql
SELECT ST_Intersects(l, p), ST_Touches(l, p),
       ST_Contains(l, p),   ST_Disjoint(l, p),
       ST_Overlaps(l, p),   ST_Crosses(l, p),
       ST_Within(l, p)
FROM (
  SELECT 'LINESTRING(0 0, 2 2)'::geometry AS l,
         'POINT(1 1)'::geometry AS p
) AS subquery;
-- st_intersects | t
-- st_touches    | f
-- st_contains   | t
-- st_disjoint   | f
-- st_overlaps   | f
-- st_crosses    | f
-- st_within     | f
```

**Diapo 127** — Quelle est la distance entre « Columbus Cir » et « Fulton Ave » ?

```sql
SELECT ST_Distance(a.geom, b.geom)
FROM nyc_streets a,
     nyc_streets b
WHERE a.name = 'Fulton Ave'
  AND b.name = 'Columbus Cir';
```

---

## 5. Jointures spatiales

*Sections 13 et 14 · diapositives 128 à 152 — script : [`scripts/05_jointures_spatiales.sql`](scripts/05_jointures_spatiales.sql)*

### Section 13 - Jointures spatiales

**Diapo 131** — Rappel - dans quel quartier se trouve la station Broad St ?

```sql
SELECT name, boroname
FROM nyc_neighborhoods
WHERE ST_Intersects(
        geom,
        ST_GeomFromText('POINT(583571 4506714)', 26918));
```

**Diapo 132** — La même chose en une seule étape, avec une jointure spatiale

```sql
SELECT s.name, n.name, n.boroname
FROM nyc_neighborhoods AS n
JOIN nyc_subway_stations AS s
  ON ST_Contains(n.geom, s.geom)
WHERE s.name = 'Broad St';
```

**Diapo 134** — Population et composition raciale des quartiers de Manhattan

```sql
SELECT n.name AS neighborhood_name,
       SUM(c.popn_total) AS population,
       100 * SUM(c.popn_white) / SUM(c.popn_total) AS white_pct,
       100 * SUM(c.popn_black) / SUM(c.popn_total) AS black_pct
FROM nyc_neighborhoods AS n
JOIN nyc_census_blocks AS c
  ON ST_Intersects(n.geom, ST_SetSRID(c.geom, 26918))
WHERE n.boroname = 'Manhattan'
GROUP BY n.name
ORDER BY white_pct DESC;
-- Résultat complet à la diapo 135 (Carnegie Hill, West Village, …)
```

**Diapo 137** — Composition raciale de toute la ville de New York

```sql
SELECT 100.0 * SUM(popn_white) / SUM(popn_total) AS white_pct,
       100.0 * SUM(popn_black) / SUM(popn_total) AS black_pct,
       SUM(popn_total) AS popn_total
FROM nyc_census_blocks;
-- 44.00395007628105 | 25.546578900241613 | 8175032
```

**Diapo 141** — Les lignes de métro sont des chaînes séparées par des virgules

```sql
SELECT DISTINCT routes
FROM nyc_subway_stations;
```

**Diapo 143** — Toutes les combinaisons de lignes qui contiennent le train A

```sql
-- La fonction strpos(routes, 'A') renvoie la position de 'A' dans routes, 0 s'il n'y est pas
SELECT DISTINCT routes
FROM nyc_subway_stations AS subways
WHERE strpos(subways.routes, 'A') > 0;
```

**Diapo 145** — Population et composition à moins de 200 m des arrêts du train A

```sql
SELECT 100 * SUM(c.popn_white) / SUM(c.popn_total) AS white_pct,
       100 * SUM(c.popn_black) / SUM(c.popn_total) AS black_pct,
       SUM(popn_total) AS popn_total
FROM nyc_census_blocks AS c
JOIN nyc_subway_stations AS s
  ON ST_DWithin(
       ST_SetSRID(c.geom, 26918),   -- Harmoniser le SRID de c.geom
       s.geom,
       200
     )
WHERE strpos(s.routes, 'A') > 0;
-- Diapo 146 : 45,59 % de Blancs et 22,09 % de Noirs le long du train A,
-- contre 44,00 % et 25,55 % pour l'ensemble de New York.
```

### Section 14 - Exercices sur les jointures spatiales

**Diapo 149** — Quelle station se trouve dans « Little Italy » ? Sur quelle ligne ?

```sql
SELECT s.name, s.routes
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
  ON ST_Contains(n.geom, s.geom)
WHERE n.name = 'Little Italy';
-- Spring St | 6
```

**Diapo 150** — Quels quartiers sont desservis par le train 6 ?

```sql
SELECT DISTINCT n.name, n.boroname
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
  ON ST_Contains(n.geom, s.geom)
WHERE strpos(s.routes, '6') > 0;
-- Midtown, Hunts Point, …
```

**Diapo 151** — Après le 11 septembre, combien de personnes ont dû être évacuées de Battery Park ?

```sql
SELECT Sum(popn_total)
FROM nyc_neighborhoods AS n
JOIN nyc_census_blocks AS c
  ON ST_Intersects(n.geom, ST_SetSRID(c.geom, 26918))   -- Harmoniser le SRID de c.geom
WHERE n.name = 'Battery Park';
-- 17153
```

**Diapo 152** — Quel quartier a la plus forte densité de population (hab./km²) ?

```sql
SELECT n.name,
       1000000 * Sum(c.popn_total) / ST_Area(n.geom) AS popn_per_sqkm
FROM nyc_census_blocks AS c
JOIN nyc_neighborhoods AS n
  ON ST_Intersects(ST_SetSRID(c.geom, 26918), n.geom)   -- Harmoniser le SRID de c.geom
GROUP BY n.name, n.geom
ORDER BY popn_per_sqkm DESC;
-- North Sutton Area | 68435.13283772678
```

---

## 6. Projection des données

*Sections 16 et 17 · diapositives 153 à 168 — script : [`scripts/06_projections.sql`](scripts/06_projections.sql)*

### Section 16 - Projection des données

**Diapo 159** — Quel est le SRID de nos stations de métro ?

```sql
SELECT ST_SRID(geom)
FROM nyc_subway_stations
LIMIT 1;
-- 26918
```

**Diapo 161** — Que signifie le SRID 26918 ?

```sql
-- Le SRID est une clé étrangère vers la table spatial_ref_sys (diapo 160).
SELECT srtext
FROM spatial_ref_sys
WHERE srid = 26918;
-- PROJCS["NAD83 / UTM zone 18N", … ]   (définition complète à la diapo 162)
-- Voir aussi : https://epsg.io/26918
```

**Diapo 163** — Les coordonnées géographiques (lon, lat) de la station Broad St

```sql
SELECT ST_AsText(ST_Transform(geom, 4326))
FROM nyc_subway_stations
WHERE name = 'Broad St';
-- POINT(-74.0106714 40.7071048)
```

### Section 17 - Exercices de projection

**Diapo 165** — Longueur de toutes les rues de New York, mesurée en UTM 18

```sql
SELECT Sum(ST_Length(geom))
FROM nyc_streets;
-- 10418904.7172
```

**Diapo 166** — Définition WKT du SRID 2831

```sql
SELECT srtext
FROM spatial_ref_sys
WHERE srid = 2831;
-- PROJCS["NAD83(HARN) / New York Long Island", …
```

**Diapo 167** — Longueur de toutes les rues, mesurée dans le SRID 2831

```sql
-- (State Plane Long Island)
SELECT Sum(ST_Length(ST_Transform(geom, 2831)))
FROM nyc_streets;
-- 10421993.706374
```

**Diapo 168** — Combien de rues traversent le 74e méridien ?

```sql
SELECT Count(*)
FROM nyc_streets
WHERE ST_Intersects(
        ST_Transform(geom, 4326),
        'SRID=4326;LINESTRING(-74 20, -74 60)'
      );
-- 223
```

---

## 7. L'indexation, pas à pas

*Diapositives 169 à 188 — script : [`scripts/07_indexation.sql`](scripts/07_indexation.sql)*

**Diapo 171** — L'index B-tree, pour les attributs (texte, nombres, dates)

```sql
-- Créer un index B-tree (type par défaut)
CREATE INDEX nyc_neighborhoods_name_idx
  ON nyc_neighborhoods (name);

-- L'index sert pour =, <, >, BETWEEN et LIKE 'Lit%' (début de chaîne)
EXPLAIN
SELECT * FROM nyc_neighborhoods
WHERE name = 'Little Italy';
```

**Diapo 173** — La boîte englobante (bounding box)

```sql
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
```

**Diapo 174** — Deux boîtes se touchent-elles ? L'opérateur &&

```sql
-- Cas de gauche : vrai
SELECT ST_MakeEnvelope(0, 0, 2, 2)
    && ST_MakeEnvelope(1, 1, 3, 3);

-- Cas de droite : faux
SELECT ST_MakeEnvelope(0, 0, 1, 1)
    && ST_MakeEnvelope(2, 1, 3, 2);

-- && compare les boîtes, jamais les formes exactes :
--   A.xmin <= B.xmax AND A.xmax >= B.xmin
--   AND A.ymin <= B.ymax AND A.ymax >= B.ymin
```

**Diapo 177** — Dans PostgreSQL, le R-tree s'appelle GiST

```sql
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
```

**Diapo 179** — Le cas du West Village - pourquoi 49 821 ≠ 26 718

```sql
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
```

**Diapo 181** — ST_DWithin, la recherche par rayon expliquée

```sql
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
```

**Diapo 182** — Le piège classique - envelopper la colonne indexée

```sql
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
```

**Diapo 183** — Le plus proche voisin avec <->

```sql
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
```

**Diapo 184** — Lire un plan d'exécution - l'index est-il utilisé ?

```sql
EXPLAIN ANALYZE
SELECT count(*)
FROM nyc_census_blocks c
JOIN nyc_subway_stations s
  ON ST_DWithin(c.geom, s.geom, 500);
-- Bon signe : « Index Scan using …_geom_idx » et une ligne « Index Cond » avec &&
-- Mauvais signe : « Seq Scan » sur nyc_census_blocks
```

**Diapo 185** — L'expérience avant / après, sans supprimer l'index

```sql
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
```

**Diapo 186** — VACUUM ANALYZE - une carte à jour pour le planificateur

(VACUUM ne s'exécute pas dans une transaction : lancez cette ligne seule)

```sql
VACUUM ANALYZE nyc_census_blocks;

-- Quand les statistiques ont-elles été calculées ?
SELECT relname,
       n_live_tup AS lignes,
       n_dead_tup AS lignes_mortes,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE relname LIKE 'nyc_%';
```

**Diapo 187** — Les types d'index de PostgreSQL (un exemple par type)

```sql
CREATE INDEX ON nyc_streets (name);                                        -- B-tree
CREATE INDEX ON nyc_census_blocks USING HASH (blkid);                      -- Hash
CREATE INDEX ON nyc_streets USING GIST (geom);                             -- GiST
CREATE INDEX ON nyc_homicides USING SPGIST (geom);                         -- SP-GiST
CREATE INDEX ON nyc_homicides USING BRIN (incident_d);                     -- BRIN
CREATE INDEX ON nyc_subway_stations USING GIN (string_to_array(routes, ',')); -- GIN
-- En pratique : B-tree pour les attributs, GiST pour les géométries.
```

**Diapo 188** — Ce que coûte un index

```sql
-- Taille de la table et de son index spatial
SELECT pg_size_pretty(pg_relation_size('nyc_census_blocks'))          AS table,
       pg_size_pretty(pg_relation_size('nyc_census_blocks_geom_idx')) AS index_gist,
       pg_size_pretty(pg_indexes_size('nyc_census_blocks'))           AS tous_les_index;
```

---

## 8. Problèmes fréquents

| Message ou symptôme | Cause probable | Solution |
|---|---|---|
| `relation "nyc_streets" does not exist` | Le Query Tool est ouvert sur la mauvaise base | Ouvrez le Query Tool sur la base qui contient les données NYC |
| `function st_astext(...) does not exist` / `type "geometry" does not exist` | PostGIS n'est pas activé dans cette base | `CREATE EXTENSION postgis;` (diapo 20) |
| `extension "postgis" already exists` | L'extension est déjà active | Rien à faire, ou utilisez `CREATE EXTENSION IF NOT EXISTS` |
| `relation "geometries" already exists` | La table de la diapo 59 a déjà été créée | `DROP TABLE geometries;` puis recommencez, ou passez à la diapo 61 |
| `Operation on mixed SRID geometries` | Les deux géométries comparées n'ont pas le même SRID | `ST_Transform` l'une vers le SRID de l'autre, ou `ST_SetSRID` si le SRID déclaré est faux |
| `syntax error at or near "’"` | Apostrophe typographique (’) copiée d'un document | Remplacez-la par une apostrophe droite (') |
| `function st_point(numeric, numeric, integer) does not exist` (diapo 89) | PostGIS antérieur à 3.2 | Utilisez `ST_SetSRID(ST_MakePoint(1, 1), 4326)` (diapo 86) |
| `VACUUM cannot run inside a transaction block` | `VACUUM` exécuté avec d'autres requêtes | Sélectionnez la ligne `VACUUM` seule, puis F5 |
| `relation "nyc_census_blocks_geom_idx" already exists` | L'index spatial existe déjà (créé à la restauration) | Normal : `CREATE INDEX IF NOT EXISTS`, ou passez à la requête suivante |
| Geometry Viewer sans fond de carte | Géométries en UTM (26918) | Affichez `ST_Transform(geom, 4326)` |
| Le Query Tool n'affiche que le dernier résultat | Plusieurs requêtes exécutées d'un coup | Sélectionnez une seule requête avant F5 |

---

*Cours GEO7531 — document de consultation.*
