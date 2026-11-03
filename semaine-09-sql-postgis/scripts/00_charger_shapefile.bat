@echo off
REM ==================================================================
REM  GEO7531 - Semaine 9 - 00 : Charger nyc_census_blocks_2000.shp
REM  Diapositives 30 (ogr2ogr) et 33 (shp2pgsql), version Windows.
REM  A lancer dans l'INVITE DE COMMANDES (cmd), pas dans psql.
REM  Sous Windows, le caractere de suite de ligne est ^ (et non \).
REM  Choisissez UNE des deux methodes : elles creent la meme table.
REM ==================================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter ---------------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
set BASE=nyc
set SHP=C:\GEO7531\data\2000\nyc_census_blocks_2000.shp
REM ------------------------------------------------------------------

set PGCLIENTENCODING=UTF8

REM ---- Methode 2 : shp2pgsql + psql (diapo 33) ---------------------
"%PG_BIN%\shp2pgsql.exe" -D -I -s 26918 "%SHP%" nyc_census_blocks_2000 | "%PG_BIN%\psql.exe" -d %BASE%

REM ---- Methode 1 : ogr2ogr (diapo 30) -------------------------------
REM  ogr2ogr est installe avec QGIS : lancez cette commande dans
REM  l'OSGeo4W Shell plutot que dans cmd.
REM
REM ogr2ogr -nln nyc_census_blocks_2000 -nlt PROMOTE_TO_MULTI ^
REM   -lco GEOMETRY_NAME=geom -lco FID=gid -lco PRECISION=NO ^
REM   PG:"dbname=nyc host=localhost user=postgres port=5432" ^
REM   C:\GEO7531\data\2000\nyc_census_blocks_2000.shp

echo.
pause
