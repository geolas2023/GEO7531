@echo off
REM ==================================================================
REM  GEO7531 - 05 : Importer un raster avec raster2pgsql (Windows)
REM  A executer dans l'INVITE DE COMMANDES (cmd), pas dans psql.
REM  Prerequis : CREATE EXTENSION postgis; CREATE EXTENSION postgis_raster;
REM ==================================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter ---------------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
set BASE=geo7531
REM Utilisez des / dans le chemin. Un motif comme C:/dossier/*.tif fonctionne aussi.
set RASTER=C:/GEO7531/donnees/mnt.tif
set TABLE=raster.mnt
REM SRID REEL du fichier (gdalinfo ou QGIS > Proprietes > Information)
set SRID=32188
REM Taille des tuiles : 100x100, 256x256 ou auto
set TUILES=100x100
REM ------------------------------------------------------------------

set PGCLIENTENCODING=UTF8

if not exist "%PG_BIN%\raster2pgsql.exe" (
  echo raster2pgsql.exe introuvable dans "%PG_BIN%".
  echo Verifiez PG_BIN et que PostGIS est installe.
  goto fin
)

echo Importation de %RASTER% vers %BASE%.%TABLE% (SRID %SRID%, tuiles %TUILES%)...
echo.

REM -I index spatial   -C contraintes raster   -M VACUUM ANALYZE
REM -t taille des tuiles   -F colonne "filename" avec le nom du fichier
REM Ajoutez -l 2,4,8 pour creer des apercus (overviews)
"%PG_BIN%\raster2pgsql.exe" -s %SRID% -I -C -M -F -t %TUILES% "%RASTER%" %TABLE% | "%PG_BIN%\psql.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %BASE% -v ON_ERROR_STOP=1

if errorlevel 1 (
  echo.
  echo *** ECHEC. Lisez le message ci-dessus et la section Depannage du tutoriel. ***
  goto fin
)

echo.
echo Verification dans raster_columns...
"%PG_BIN%\psql.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %BASE% -c "SELECT r_table_schema, r_table_name, srid, scale_x, num_bands, pixel_types FROM raster_columns;" -c "SELECT count(*) AS nb_tuiles FROM %TABLE%;"

:fin
echo.
pause
endlocal
