# GEO7531 — Installer les principales extensions de géomatique dans PostgreSQL

PostGIS n'est pas la seule extension utile en géomatique. Ce tutoriel explique ce qu'est une extension, comment l'installer sur votre ordinateur et l'activer dans une base, puis présente les extensions principales avec le code SQL pour les activer et les essayer sur les données NYC du cours.

> **Pour qui ?** Étudiant·e·s qui ont suivi le tutoriel [Créer, restaurer et sauvegarder une base](../README.md) et qui disposent de la base contenant les données NYC.

---

## Table des matières

1. [Comprendre : disponible ≠ activée](#1-comprendre--disponible--activée)
2. [Installer les extensions sur l'ordinateur](#2-installer-les-extensions-sur-lordinateur)
3. [Vérifier ce qui est disponible et activé](#3-vérifier-ce-qui-est-disponible-et-activé)
4. [Les extensions, une par une](#4-les-extensions-une-par-une)
   - [4.1 Le cœur de PostGIS](#41-le-cœur-de-postgis)
   - [4.2 Noms de lieux et adresses](#42-noms-de-lieux-et-adresses)
   - [4.3 Réseaux et itinéraires : pgRouting](#43-réseaux-et-itinéraires--pgrouting)
   - [4.4 LiDAR : pointcloud](#44-lidar--pointcloud)
   - [4.5 Lire des données externes : ogr_fdw et postgres_fdw](#45-lire-des-données-externes--ogr_fdw-et-postgres_fdw)
   - [4.6 Grilles hexagonales : H3](#46-grilles-hexagonales--h3)
   - [4.7 Utilitaires : hstore et btree_gist](#47-utilitaires--hstore-et-btree_gist)
   - [4.8 Extensions qui exigent une configuration : MobilityDB, pg_stat_statements](#48-extensions-qui-exigent-une-configuration)
5. [Tout activer d'un coup](#5-tout-activer-dun-coup)
6. [Mettre à jour, supprimer, base modèle](#6-mettre-à-jour-supprimer-base-modèle)
7. [Problèmes fréquents](#7-problèmes-fréquents)
8. [Références](#8-références)

Fichiers utiles dans ce dossier :

| Script | Rôle |
|---|---|
| [`scripts/01_lister_extensions.sql`](scripts/01_lister_extensions.sql) | Voir les extensions disponibles et activées (ne modifie rien) |
| [`scripts/02_installer_extensions.sql`](scripts/02_installer_extensions.sql) | Activer toutes les extensions de géomatique dans une base |
| [`scripts/03_tester_extensions.sql`](scripts/03_tester_extensions.sql) | Un test court par extension, sur les données NYC |
| [`scripts/04_pgrouting_nyc.sql`](scripts/04_pgrouting_nyc.sql) | Premier itinéraire et zone accessible à pied avec pgRouting |
| [`scripts/05_entretien_extensions.sql`](scripts/05_entretien_extensions.sql) | Mettre à jour, déplacer, supprimer ; base modèle |
| [`scripts/installer_extensions.bat`](scripts/installer_extensions.bat) | Lance le script 02 avec psql (Windows) |

---

## 1. Comprendre : disponible ≠ activée

Une extension ajoute à PostgreSQL de nouveaux **types** (`geometry`, `raster`…), de nouvelles **fonctions** (`ST_Intersects`, `pgr_dijkstra`…) et parfois de nouveaux **index**. Son installation se fait en deux temps, à deux endroits différents :

| Étape | Où ? | Comment | Combien de fois ? |
|---|---|---|---|
| **1. Installer** les fichiers de l'extension | Sur l'**ordinateur** (le serveur PostgreSQL) | Stack Builder (Windows), `apt` (Linux)… | Une fois par ordinateur |
| **2. Activer** l'extension | Dans **chaque base de données** | `CREATE EXTENSION nom;` en SQL | Une fois **par base** |

> 💡 **Analogie :** installer une application sur votre téléphone (étape 1), puis l'activer dans chaque compte qui doit s'en servir (étape 2). Une base créée hier avec PostGIS ne rend pas PostGIS actif dans la base créée aujourd'hui.

Conséquences pratiques :

- `CREATE EXTENSION postgis;` échoue avec `could not open extension control file` si l'étape 1 n'a pas été faite.
- `type "geometry" does not exist` signifie que l'étape 2 n'a pas été faite **dans cette base**.
- Il faut généralement être connecté en **superutilisateur** (`postgres`) pour activer une extension.

---

## 2. Installer les extensions sur l'ordinateur

### Windows : Stack Builder et le « PostGIS Bundle »

Le *PostGIS Bundle* pour Windows installe en une fois la plupart des extensions de ce tutoriel : PostGIS (avec raster, topologie, SFCGAL, géocodeur TIGER et `address_standardizer`), pgRouting, ogr_fdw, pgpointcloud, h3-pg, MobilityDB et pgSphere, ainsi que les outils `shp2pgsql`, `raster2pgsql` et `osm2pgrouting`.

1. Menu Démarrer → **PostgreSQL 16 → Application Stack Builder**.
2. Choisissez votre serveur : **PostgreSQL 16 on port 5432**, puis **Next**.
3. Dépliez **Spatial Extensions** et cochez **PostGIS 3.x Bundle for PostgreSQL 16**.
4. Suivez l'assistant. Quand il propose de créer une base d'exemple, vous pouvez refuser.
5. Acceptez les questions sur les variables d'environnement GDAL (raster) si elles apparaissent.

> ⚠️ Prenez le Bundle qui correspond **à votre version de PostgreSQL** : un Bundle pour PostgreSQL 17 ne fonctionne pas avec un serveur PostgreSQL 16.

Les extensions de la famille *contrib* (`fuzzystrmatch`, `pg_trgm`, `unaccent`, `hstore`, `btree_gist`, `postgres_fdw`, `pg_stat_statements`) sont déjà livrées avec PostgreSQL : rien à installer.

### Linux (Ubuntu / Debian, dépôt PGDG)

```bash
sudo apt install postgresql-16-postgis-3 postgresql-16-pgrouting \
                 postgresql-16-pointcloud postgresql-16-ogr-fdw \
                 postgresql-16-h3 postgresql-16-mobilitydb
```

Remplacez `16` par votre version de PostgreSQL.

### macOS et services infonuagiques

- **Postgres.app** (macOS) inclut PostGIS. Pour les autres extensions, vérifiez la liste avec le script 01.
- **Services gérés** (Amazon RDS, Azure, Google Cloud SQL…) : PostGIS et pgRouting sont généralement proposés, mais chaque service a sa propre liste d'extensions permises. Vérifiez avec le script 01 avant de planifier un projet.

---

## 3. Vérifier ce qui est disponible et activé

Ouvrez le **Query Tool** sur votre base (clic droit sur la base → *Query Tool*) et exécutez [`scripts/01_lister_extensions.sql`](scripts/01_lister_extensions.sql). La requête principale :

```sql
SELECT name, default_version, installed_version, comment
FROM pg_available_extensions
WHERE name IN ('postgis', 'postgis_raster', 'pgrouting', 'h3', 'ogr_fdw', 'pointcloud')
ORDER BY name;
```

| Résultat | Signification | Que faire ? |
|---|---|---|
| La ligne n'apparaît pas | Extension **non installée** sur l'ordinateur | Section 2 |
| `installed_version` est vide | **Disponible** mais pas activée dans cette base | `CREATE EXTENSION …;` |
| `installed_version` est rempli | **Activée** dans cette base | Rien |

Dans **psql**, la méta-commande `\dx` liste les extensions activées, et `\dx+ postgis` liste toutes leurs fonctions.

Dans **pgAdmin**, dépliez la base → **Extensions** : seules les extensions activées y figurent.

---

## 4. Les extensions, une par une

Chaque section donne le rôle de l'extension, la commande pour l'activer et un petit test sur les données NYC. Tous les tests sont regroupés dans [`scripts/03_tester_extensions.sql`](scripts/03_tester_extensions.sql).

Tableau récapitulatif :

| Extension | Sert à… | Indispensable pour le cours ? |
|---|---|---|
| `postgis` | Géométries vectorielles, fonctions `ST_*` | ✅ Oui |
| `postgis_raster` | Données matricielles (MNT, images) | ✅ Oui |
| `postgis_topology` | Limites partagées entre polygones voisins | Utile |
| `postgis_sfcgal` | Géométrie 3D : extrusion, volumes | Utile |
| `fuzzystrmatch`, `pg_trgm`, `unaccent` | Rechercher des noms malgré fautes et accents | Utile |
| `address_standardizer`, `postgis_tiger_geocoder` | Adresses américaines | Facultatif |
| `pgrouting` | Plus court chemin, zones de desserte | Utile |
| `pointcloud`, `pointcloud_postgis` | Nuages de points LiDAR | Facultatif |
| `ogr_fdw` | Lire un shapefile, GeoPackage, CSV… sans l'importer | Utile |
| `postgres_fdw` | Lire les tables d'une autre base PostgreSQL | Facultatif |
| `h3`, `h3_postgis` | Agréger des points dans des hexagones | Utile |
| `hstore` | Étiquettes clé=valeur (OpenStreetMap) | Facultatif |
| `btree_gist` | Index mixte attribut + géométrie | Facultatif |
| `mobilitydb` | Trajectoires (GPS, véhicules) | Facultatif, configuration requise |
| `pg_stat_statements` | Repérer les requêtes lentes | Facultatif, configuration requise |

### 4.1 Le cœur de PostGIS

```sql
CREATE EXTENSION IF NOT EXISTS postgis;            -- geometry, geography, ST_*
CREATE EXTENSION IF NOT EXISTS postgis_raster;     -- type raster
CREATE EXTENSION IF NOT EXISTS postgis_topology;   -- topologie
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;     -- 3D avancée
```

**`postgis`** — La base de tout : les types `geometry` et `geography`, les systèmes de coordonnées (`spatial_ref_sys`), les index spatiaux GiST et plusieurs centaines de fonctions `ST_*`.

```sql
SELECT name, ST_AsText(ST_Transform(geom, 4326)) AS wgs84
FROM nyc_subway_stations
WHERE name = 'Broad St';
```

**`postgis_raster`** — Depuis PostGIS 3, le raster est une extension séparée. Sans elle, `raster2pgsql` échoue avec `type "raster" does not exist`. Test : transformer un quartier en pixels de 50 m.

```sql
SELECT name, ST_Width(r) AS colonnes, ST_Height(r) AS lignes
FROM (SELECT name, ST_AsRaster(geom, 50.0, -50.0, '8BUI', 1, 0) AS r
      FROM nyc_neighborhoods WHERE name = 'West Village') AS t;
```

Pour l'importation et le traitement de vrais rasters (NDVI, MNT), voir le tutoriel [Importer des données dans PostGIS](../importation-postgis/README.md), sections 7 et 8.

**`postgis_topology`** — Dans une couche « simple » de polygones, la limite commune de deux quartiers voisins est stockée **deux fois**, et rien ne garantit qu'elle soit identique des deux côtés (trous, chevauchements). En topologie, cette limite est une **arête** stockée une seule fois et partagée par deux **faces**. On l'utilise pour le cadastre, les découpages administratifs et la généralisation sans créer de trous.

```sql
SELECT topology.CreateTopology('topo_demo');
SELECT topology.ST_CreateTopoGeo('topo_demo',
  'GEOMETRYCOLLECTION(POLYGON((0 0,10 0,10 10,0 10,0 0)),
                      POLYGON((10 0,20 0,20 10,10 10,10 0)))');
SELECT count(*) FROM topo_demo.edge;     -- l'arête commune n'y est qu'une fois
SELECT topology.DropTopology('topo_demo');
```

**`postgis_sfcgal`** — Ajoute des calculs 3D exacts : extrusion (bâtiments en 3D à partir d'emprises), volumes, squelettes droits, enveloppes concaves avancées.

```sql
-- Emprise de 100 m × 50 m extrudée sur 30 m de haut
SELECT CG_Volume(CG_MakeSolid(
         CG_Extrude(ST_MakeEnvelope(0, 0, 100, 50, 26918), 0, 0, 30)
       )) AS volume_m3;   -- 150 000
```

> ℹ️ Depuis PostGIS 3.5, les fonctions SFCGAL portent le préfixe `CG_`. Avec une version plus ancienne, écrivez `ST_Volume`, `ST_MakeSolid` et `ST_Extrude`.

### 4.2 Noms de lieux et adresses

```sql
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS address_standardizer;
CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
```

Les toponymes sont saisis avec des fautes, des accents ou des abréviations. Ces extensions permettent de les retrouver quand même, ce qui est essentiel pour joindre deux sources de données par le nom.

**`fuzzystrmatch`** — Distance de Levenshtein (nombre de lettres à modifier), `soundex` et `dmetaphone` (ressemblance phonétique).

```sql
SELECT name, levenshtein(name, 'Grenwich Vilage') AS nb_modifications
FROM nyc_neighborhoods
ORDER BY nb_modifications
LIMIT 3;
```

**`pg_trgm`** — Similarité entre 0 et 1, opérateur `%` (« assez semblable »), et surtout un **index** qui accélère ces recherches ainsi que `LIKE '%texte%'`.

```sql
SELECT name, similarity(name, 'washington hights') AS sim
FROM nyc_neighborhoods
WHERE name % 'washington hights'
ORDER BY sim DESC;

CREATE INDEX nyc_streets_name_trgm_idx
  ON nyc_streets USING GIN (name gin_trgm_ops);
```

**`unaccent`** — Enlève les accents. Indispensable au Québec pour comparer `Île-Bizard` et `ile-bizard`.

```sql
SELECT unaccent('Montréal, Trois-Rivières, Québec');
```

**`address_standardizer`** et **`postgis_tiger_geocoder`** — Découpent une adresse en éléments (numéro, rue, type de voie, ville, code postal) et, pour le géocodeur, la convertissent en point à partir des données du recensement américain (TIGER). Ils fonctionnent pour les **adresses américaines** ; ils conviennent donc aux données NYC, mais pas aux adresses québécoises.

```sql
SELECT house_num, name, suftype, city, state, postcode
FROM standardize_address('us_lex', 'us_gaz', 'us_rules',
                         '350 Fifth Avenue', 'New York, NY 10118');
```

> ℹ️ Le géocodage complet exige de télécharger et charger les données TIGER de l'État de New York (plusieurs gigaoctets). La normalisation (`tiger.normalize_address`) fonctionne sans ces données. Pour géocoder des adresses du Québec, utilisez plutôt Adresses Québec ou un service externe, puis importez les résultats.

### 4.3 Réseaux et itinéraires : pgRouting

```sql
CREATE EXTENSION IF NOT EXISTS pgrouting;
SELECT pgr_version();
```

pgRouting transforme une couche de lignes en **graphe** (des nœuds reliés par des arêtes avec un coût) et calcule :

- le plus court chemin entre deux points (`pgr_dijkstra`, `pgr_aStar`) ;
- la zone accessible en X mètres ou X minutes de réseau (`pgr_drivingDistance`) : bien plus réaliste qu'une zone tampon circulaire ;
- les problèmes du voyageur de commerce, les composantes connexes, etc.

Les étapes, appliquées aux rues de NYC dans [`scripts/04_pgrouting_nyc.sql`](scripts/04_pgrouting_nyc.sql) :

1. Créer une table d'**arêtes** : une ligne simple par tronçon, avec un `id` et un `cost` (la longueur).
2. Extraire les **nœuds** avec `pgr_extractVertices`, puis remplir `source` et `target` pour chaque tronçon.
3. Calculer l'itinéraire entre les stations *Broad St* et *Whitehall St* avec `pgr_dijkstra`.
4. Tracer la zone accessible à 500 m de marche avec `pgr_drivingDistance`.

Le cœur du calcul :

```sql
SELECT d.seq, r.name, r.cost
FROM pgr_dijkstra(
       'SELECT id, source, target, cost, cost AS reverse_cost FROM reseau',
       1234,  5678,            -- identifiants des nœuds de départ et d'arrivée
       directed := false) AS d
JOIN reseau AS r ON r.id = d.edge
ORDER BY d.seq;
```

> ⚠️ **pgRouting 4 :** l'ancienne fonction `pgr_createTopology`, encore citée dans de nombreux tutoriels en ligne, est dépréciée depuis la version 3.8 et n'existe plus dans pgRouting 4. Le script 04 utilise la méthode actuelle (`pgr_extractVertices`), qui fonctionne avec les deux versions.

### 4.4 LiDAR : pointcloud

```sql
CREATE EXTENSION IF NOT EXISTS pointcloud;
CREATE EXTENSION IF NOT EXISTS pointcloud_postgis;
SELECT PC_Version();
```

Un nuage LiDAR compte des millions de points. Les stocker un par un en `geometry` serait énorme et lent. `pointcloud` les regroupe en **patchs** (`pcpatch`, par exemple 400 points par patch) compressés, avec tous leurs attributs (intensité, classification, numéro de retour). `pointcloud_postgis` fait le lien avec PostGIS : enveloppe d'un patch, intersection avec un polygone, conversion en points.

L'importation se fait avec PDAL. Voir le tutoriel [Importer des données dans PostGIS](../importation-postgis/README.md), section 9.

### 4.5 Lire des données externes : ogr_fdw et postgres_fdw

Un *Foreign Data Wrapper* (FDW) affiche des données externes **comme des tables**, sans les importer. On peut les interroger en SQL et les joindre à des tables PostGIS.

**`ogr_fdw`** — Lit tout ce que GDAL/OGR sait lire : shapefile, GeoPackage, GeoJSON, CSV, Excel, fichier géodatabase (FileGDB), services WFS…

```sql
CREATE EXTENSION IF NOT EXISTS ogr_fdw;

-- Un « serveur » = une source de données (ici un dossier de shapefiles)
CREATE SERVER shp_nyc
  FOREIGN DATA WRAPPER ogr_fdw
  OPTIONS (datasource 'C:/GEO7531/data', format 'ESRI Shapefile');

-- Chaque shapefile du dossier devient une table du schéma externe
CREATE SCHEMA externe;
IMPORT FOREIGN SCHEMA ogr_all FROM SERVER shp_nyc INTO externe;

SELECT foreign_table_name FROM information_schema.foreign_tables
WHERE foreign_table_schema = 'externe';
```

> ⚠️ C'est le **service PostgreSQL** qui lit le fichier, pas votre compte Windows. Utilisez un dossier simple comme `C:\GEO7531\data`, pas votre Bureau ni OneDrive, et écrivez le chemin avec des `/`.

Quand l'utiliser ? Pour consulter rapidement un fichier, ou pour une source mise à jour par quelqu'un d'autre. Pour des analyses répétées, importez plutôt les données (`shp2pgsql`, `ogr2ogr`) : vous aurez des index spatiaux et des requêtes bien plus rapides.

L'outil en ligne de commande `ogr_fdw_info` (dans le dossier `bin` de PostgreSQL) affiche les commandes `CREATE SERVER` et `CREATE FOREIGN TABLE` adaptées à un fichier :

```
ogr_fdw_info -s C:/GEO7531/data -l nyc_streets
```

**`postgres_fdw`** — Même principe pour les tables d'une **autre base PostgreSQL**, sur le même serveur ou sur un autre ordinateur. Utile pour croiser vos données avec la base d'un collègue sans tout copier.

### 4.6 Grilles hexagonales : H3

```sql
CREATE EXTENSION IF NOT EXISTS h3;
CREATE EXTENSION IF NOT EXISTS h3_postgis;
```

H3 découpe la Terre entière en **hexagones** emboîtés, à 16 résolutions (de 4 millions de km² à moins de 1 m²). Chaque hexagone a un identifiant unique. Agréger des points par hexagone donne des cartes de densité comparables d'une ville à l'autre, sans dépendre de découpages administratifs de tailles différentes.

```sql
-- Homicides par hexagone de résolution 8 (environ 0,7 km²)
CREATE TABLE homicides_h3 AS
SELECT cellule,
       count(*) AS nb_homicides,
       h3_cell_to_boundary_geometry(cellule) AS geom
FROM (SELECT h3_lat_lng_to_cell(ST_Transform(geom, 4326), 8) AS cellule
      FROM nyc_homicides) AS t
GROUP BY cellule;
```

Ajoutez `homicides_h3` dans QGIS et appliquez un style gradué sur `nb_homicides`.

> ⚠️ H3 travaille en latitude/longitude : transformez toujours vos géométries en EPSG:4326 avant de les passer à `h3_lat_lng_to_cell`.

### 4.7 Utilitaires : hstore et btree_gist

**`hstore`** — Stocke des paires `clé=valeur` dans une seule colonne. C'est le format des étiquettes OpenStreetMap quand on les importe avec `osm2pgsql --hstore`.

```sql
CREATE EXTENSION IF NOT EXISTS hstore;
SELECT 'amenity=>library, name=>"Bibliothèque"'::hstore -> 'amenity';
```

**`btree_gist`** — Permet de combiner un attribut ordinaire et une géométrie dans **un seul index GiST**.

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE INDEX nyc_census_blocks_boro_geom_idx
  ON nyc_census_blocks USING GIST (boroname, geom);
```

### 4.8 Extensions qui exigent une configuration

Ces deux extensions doivent être **chargées au démarrage du serveur**. Il faut modifier le fichier `postgresql.conf` puis redémarrer le service PostgreSQL. Sous Windows, ce fichier se trouve par défaut dans `C:\Program Files\PostgreSQL\16\data\`. On peut aussi trouver son emplacement avec `SHOW config_file;`.

**MobilityDB** — Trajectoires : positions qui changent dans le temps (GPS, autobus, animaux suivis). Types `tgeompoint`, calcul de vitesses, de distances parcourues, de rencontres entre deux objets mobiles.

Dans `postgresql.conf` :

```
shared_preload_libraries = 'postgis-3'
max_locks_per_transaction = 128
```

Redémarrez le service, puis :

```sql
CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;
```

**`pg_stat_statements`** — Enregistre toutes les requêtes exécutées et leur durée totale : pratique pour trouver les requêtes à optimiser (voir le module sur l'indexation du cours).

```
shared_preload_libraries = 'pg_stat_statements'
```

> ⚠️ `shared_preload_libraries` est **une seule ligne**. Pour charger les deux, séparez les noms par une virgule : `shared_preload_libraries = 'postgis-3,pg_stat_statements'`. Une faute de frappe sur cette ligne empêche le serveur de démarrer : faites une copie du fichier avant de le modifier.

---

## 5. Tout activer d'un coup

**Dans pgAdmin :** ouvrez le Query Tool sur votre base, ouvrez [`scripts/02_installer_extensions.sql`](scripts/02_installer_extensions.sql) (icône de dossier) et exécutez-le **bloc par bloc** (sélectionnez un bloc, puis F5). Si une extension n'est pas disponible, seul son bloc échoue.

**Dans psql :**

```
\i C:/GEO7531/extensions-postgis/scripts/02_installer_extensions.sql
```

**Par double-clic (Windows) :** adaptez `PG_BIN` et `BASE` au début de [`scripts/installer_extensions.bat`](scripts/installer_extensions.bat), puis lancez-le. Le script continue même si une extension manque, et affiche à la fin la liste des extensions activées.

Vérifiez ensuite avec [`scripts/03_tester_extensions.sql`](scripts/03_tester_extensions.sql).

> 💡 **Activez seulement ce dont vous avez besoin.** Une extension inutilisée ne ralentit pas la base, mais elle encombre la liste des fonctions et doit être disponible sur tout serveur où vous restaurerez la base (voir section 7).

---

## 6. Mettre à jour, supprimer, base modèle

Tout est dans [`scripts/05_entretien_extensions.sql`](scripts/05_entretien_extensions.sql). L'essentiel :

```sql
-- Après l'installation d'un nouveau Bundle : mettre à jour la base
SELECT postgis_extensions_upgrade();   -- toutes les extensions postgis_*
ALTER EXTENSION pgrouting UPDATE;      -- les autres, une par une

-- Créer chaque nouvelle base à partir d'une base modèle déjà équipée
CREATE DATABASE tp1 TEMPLATE modele_geo7531;
```

> ⚠️ **`DROP EXTENSION postgis CASCADE` efface toutes les colonnes `geometry` de la base, avec leurs données.** `CASCADE` supprime tout ce qui dépend de l'extension. Sans `CASCADE`, PostgreSQL refuse la suppression si quelque chose en dépend : c'est l'option prudente.

---

## 7. Problèmes fréquents

| Message ou symptôme | Cause probable | Solution |
|---|---|---|
| `could not open extension control file ".../postgis.control"` | Extension non installée sur l'ordinateur | Section 2 : Stack Builder → PostGIS Bundle |
| `type "geometry" does not exist` | PostGIS non activé **dans cette base** | `CREATE EXTENSION postgis;` dans la bonne base |
| `type "raster" does not exist` | `postgis_raster` non activé (PostGIS 3+) | `CREATE EXTENSION postgis_raster;` |
| `permission denied to create extension` | Vous n'êtes pas superutilisateur | Connectez-vous en `postgres` |
| `required extension "postgis" is not installed` | Dépendance manquante | Activez d'abord `postgis`, ou ajoutez `CASCADE` : `CREATE EXTENSION h3_postgis CASCADE;` |
| `function pgr_createtopology(...) does not exist` | pgRouting 4 : fonction retirée | Utilisez `pgr_extractVertices` (script 04) |
| `function cg_extrude(...) does not exist` | PostGIS antérieur à 3.5 | Utilisez `ST_Extrude`, `ST_MakeSolid`, `ST_Volume` |
| `function normalize_address(...) does not exist` | Le schéma `tiger` n'est pas dans le `search_path` | Écrivez `tiger.normalize_address(...)` |
| MobilityDB : `could not load library` | PostGIS non préchargé | `shared_preload_libraries = 'postgis-3'`, puis redémarrer le service |
| Le service ne redémarre plus après modification de `postgresql.conf` | Faute de frappe dans `shared_preload_libraries` | Restaurez la copie du fichier ; consultez le journal dans `data\log\` |
| Restauration d'une sauvegarde : `could not open extension control file ".../h3.control"` | L'autre ordinateur n'a pas cette extension | Installez le même Bundle sur l'ordinateur qui restaure |
| ogr_fdw : `unable to open datasource` | Le service PostgreSQL ne peut pas lire le dossier | Dossier simple (`C:/GEO7531/data`), pas OneDrive ni le Bureau ; chemin avec `/` |
| Bundle installé mais extensions absentes de la liste | Bundle d'une autre version de PostgreSQL | Réinstallez le Bundle pour **votre** version (16) |

---

## 8. Références

- [PostGIS : installation sous Windows et contenu du Bundle](https://postgis.net/documentation/getting_started/install_windows/released_versions/)
- [PostGIS : activer PostGIS et les extensions du Bundle](https://postgis.net/documentation/getting_started/install_windows/enabling_postgis/)
- [Documentation PostGIS (en français)](https://postgis.net/docs/manual-3.5/fr/)
- [pgRouting : guide de migration (pgr_createTopology → pgr_extractVertices)](https://docs.pgrouting.org/3.8/en/migration.html)
- [MobilityDB : installation](https://github.com/MobilityDB/MobilityDB)
- [Documentation PostgreSQL : modules *contrib* (pg_trgm, unaccent, hstore…)](https://www.postgresql.org/docs/16/contrib.html)

---

*Cours GEO7531 — document de consultation.*
