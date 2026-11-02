@echo off
REM ==================================================================
REM  GEO7531 - 03 : Importer un shapefile avec shp2pgsql (Windows)
REM  A executer dans l'INVITE DE COMMANDES (cmd), pas dans psql.
REM  Modifiez les parametres ci-dessous puis double-cliquez.
REM ==================================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter ---------------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
set BASE=geo7531
set SHP=C:\GEO7531\donnees\arrondissements.shp
set TABLE=vecteur.arrondissements
set SRID=32188
REM Encodage des attributs du .dbf : UTF-8 ou LATIN1
set ENCODAGE=UTF-8
REM ------------------------------------------------------------------

set PGCLIENTENCODING=UTF8

if not exist "%PG_BIN%\shp2pgsql.exe" (
  echo shp2pgsql.exe introuvable dans "%PG_BIN%".
  echo Verifiez PG_BIN et que PostGIS est installe.
  goto fin
)
if not exist "%SHP%" (
  echo Shapefile introuvable : %SHP%
  goto fin
)

echo Importation de %SHP% vers %BASE%.%TABLE% (SRID %SRID%)...
echo.

REM -c : cree la table (remplacer par -d pour la recreer, -a pour ajouter)
REM -I : index spatial      -D : format rapide (COPY)
"%PG_BIN%\shp2pgsql.exe" -c -D -I -s %SRID% -W %ENCODAGE% "%SHP%" %TABLE% | "%PG_BIN%\psql.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %BASE% -v ON_ERROR_STOP=1 -q

if errorlevel 1 (
  echo.
  echo *** ECHEC. Lisez le message ci-dessus et la section Depannage du tutoriel. ***
  goto fin
)

echo.
echo Mise a jour des statistiques et verification...
"%PG_BIN%\psql.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d %BASE% -c "ANALYZE %TABLE%;" -c "SELECT f_table_schema, f_table_name, type, srid FROM geometry_columns WHERE f_table_schema||'.'||f_table_name = '%TABLE%';" -c "SELECT count(*) AS nb_entites FROM %TABLE%;"

:fin
echo.
pause
endlocal
