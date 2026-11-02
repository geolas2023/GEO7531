@echo off
REM ==================================================================
REM  GEO7531 - 04 : Importer GeoJSON / KML / GPKG avec ogr2ogr
REM  A executer dans le OSGeo4W Shell (installe avec QGIS).
REM  Decommentez (retirez REM) l'exemple voulu et adaptez les chemins.
REM ==================================================================
setlocal

set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
set BASE=geo7531
REM ogr2ogr ne demande pas le mot de passe : indiquez-le ici
set PGPASSWORD=votre_mot_de_passe

set PG=PG:"host=%PGHOST% port=%PGPORT% dbname=%BASE% user=%PGUSER%"

where ogr2ogr >nul 2>nul || (
  echo ogr2ogr introuvable. Ouvrez le "OSGeo4W Shell" installe avec QGIS.
  goto fin
)

REM ---- Exemple 1 : GeoJSON, reprojete en MTM 8 ----------------------
ogr2ogr -f PostgreSQL %PG% "C:\GEO7531\donnees\quartiers.geojson" -nln vecteur.quartiers -t_srs EPSG:32188 -nlt PROMOTE_TO_MULTI -lco GEOMETRY_NAME=geom -lco FID=gid -overwrite -progress

REM ---- Exemple 2 : KML (2D) -------------------------------------------
REM ogrinfo "C:\GEO7531\donnees\sentiers.kml"
REM ogr2ogr -f PostgreSQL %PG% "C:\GEO7531\donnees\sentiers.kml" -nln vecteur.sentiers -t_srs EPSG:32188 -dim XY -nlt PROMOTE_TO_MULTI -lco GEOMETRY_NAME=geom -overwrite

REM ---- Exemple 3 : une couche d'un GeoPackage -------------------------
REM ogrinfo "C:\GEO7531\donnees\donnees.gpkg"
REM ogr2ogr -f PostgreSQL %PG% "C:\GEO7531\donnees\donnees.gpkg" parcs -nln vecteur.parcs -t_srs EPSG:32188 -lco GEOMETRY_NAME=geom -overwrite

REM ---- Exemple 4 : CSV avec longitude/latitude ------------------------
REM ogr2ogr -f PostgreSQL %PG% "C:\GEO7531\importation-postgis\donnees_exemple\stations_exemple.csv" -oo X_POSSIBLE_NAMES=longitude -oo Y_POSSIBLE_NAMES=latitude -oo SEPARATOR=SEMICOLON -s_srs EPSG:4326 -t_srs EPSG:32188 -nln vecteur.stations_ogr -lco GEOMETRY_NAME=geom -overwrite

REM ---- Exemple 5 : export PostGIS vers GeoPackage ---------------------
REM ogr2ogr -f GPKG "C:\GEO7531\export.gpkg" %PG% vecteur.quartiers

if errorlevel 1 (echo *** ECHEC : voir le message ci-dessus. ***) else (echo Termine.)

:fin
set PGPASSWORD=
pause
endlocal
