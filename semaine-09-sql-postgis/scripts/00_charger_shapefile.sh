#!/usr/bin/env bash
# =====================================================================
#  GEO7531 - Semaine 9 - 00 : Charger nyc_census_blocks_2000.shp
#  Diapositives 30 (ogr2ogr) et 33 (shp2pgsql)
#  À lancer dans un terminal (pas dans psql), depuis le dossier
#  qui contient nyc_census_blocks_2000.shp.
#  Choisissez UNE des deux méthodes : elles créent la même table.
# =====================================================================

# ---- Méthode 1 : ogr2ogr (diapo 30) ---------------------------------
#   -nln  : nom de la nouvelle couche (table)
#   -nlt  : type de géométrie (PROMOTE_TO_MULTI = tout en Multi*)
#   -lco GEOMETRY_NAME : nom de la colonne géométrique
#   -lco FID           : nom de la clé primaire
#   -lco PRECISION=NO  : ne pas imposer la précision des champs du .dbf
ogr2ogr \
  -nln nyc_census_blocks_2000 \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -lco FID=gid \
  -lco PRECISION=NO \
  Pg:'dbname=nyc host=localhost user=postgres port=5432' \
  nyc_census_blocks_2000.shp

# ---- Méthode 2 : shp2pgsql + psql (diapo 33) ------------------------
#   -D        : format « dump » (COPY), plus rapide
#   -I        : construire un index spatial
#   -s 26918  : identifiant de référence spatiale (SRID) des données
# shp2pgsql \
#   -D \
#   -I \
#   -s 26918 \
#   nyc_census_blocks_2000.shp \
#   nyc_census_blocks_2000 \
#   | psql dbname=nyc user=postgres host=localhost
