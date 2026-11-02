@echo off
REM ============================================================
REM  GEO7531 - Restauration d'une base PostgreSQL/PostGIS (Windows)
REM  Usage : double-cliquer, ou dans un terminal :
REM          restauration.bat fichier.backup nom_nouvelle_base
REM  La base cible est CREEE par le script : elle ne doit pas exister.
REM ============================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter --------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
REM ----------------------------------------------------------

set FICHIER=%~1
set BASE=%~2
if "%FICHIER%"=="" set /p FICHIER=Chemin du fichier .backup :
if "%BASE%"=="" set /p BASE=Nom de la NOUVELLE base a creer :

REM Retirer d'eventuels guillemets saisis
set FICHIER=%FICHIER:"=%

if not exist "%FICHIER%" (
  echo Fichier introuvable : %FICHIER%
  goto fin
)
if not exist "%PG_BIN%\pg_restore.exe" (
  echo pg_restore introuvable dans "%PG_BIN%".
  echo Modifiez la variable PG_BIN en haut de ce script.
  goto fin
)

echo.
echo Le mot de passe de %PGUSER% peut etre demande a chaque etape.
echo Astuce : definissez PGPASSWORD dans ce terminal pour eviter de le retaper.
echo.

echo [1/3] Creation de la base "%BASE%"...
"%PG_BIN%\createdb.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -E UTF8 "%BASE%"
if errorlevel 1 (
  echo *** Impossible de creer la base. Existe-t-elle deja ? ***
  goto fin
)

echo [2/3] Activation de PostGIS...
"%PG_BIN%\psql.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d "%BASE%" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
if errorlevel 1 echo (PostGIS non disponible : on continue sans.)

echo [3/3] Restauration de "%FICHIER%"...
"%PG_BIN%\pg_restore.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -d "%BASE%" --no-owner --no-privileges --single-transaction -v "%FICHIER%"

if errorlevel 1 (
  echo.
  echo *** La restauration a echoue : aucune donnee n'a ete importee. ***
  echo Lisez le premier message d'erreur ci-dessus. Voir aussi la section
  echo "Problemes frequents" du README.
) else (
  echo.
  echo Restauration terminee dans la base "%BASE%".
  echo Dans pgAdmin : clic droit sur Databases ^> Refresh.
)

:fin
echo.
pause
endlocal
