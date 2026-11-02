@echo off
REM ============================================================
REM  GEO7531 - Sauvegarde d'une base PostgreSQL/PostGIS (Windows)
REM  Usage : double-cliquer, ou dans un terminal :
REM          sauvegarde.bat nom_de_la_base
REM ============================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter --------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
set DOSSIER=C:\GEO7531\sauvegardes
REM ----------------------------------------------------------

set BASE=%~1
if "%BASE%"=="" set /p BASE=Nom de la base a sauvegarder :
if "%BASE%"=="" (
  echo Aucun nom de base fourni.
  goto fin
)

if not exist "%PG_BIN%\pg_dump.exe" (
  echo pg_dump introuvable dans "%PG_BIN%".
  echo Modifiez la variable PG_BIN en haut de ce script.
  goto fin
)

if not exist "%DOSSIER%" mkdir "%DOSSIER%"

REM Horodatage AAAAMMJJ_HHMM independant de la langue de Windows
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmm"') do set HORO=%%i
set FICHIER=%DOSSIER%\%BASE%_%HORO%.backup

echo.
echo Sauvegarde de "%BASE%" vers :
echo   %FICHIER%
echo (le mot de passe de %PGUSER% sera demande)
echo.

"%PG_BIN%\pg_dump.exe" -h %PGHOST% -p %PGPORT% -U %PGUSER% -F c -E UTF8 -v -f "%FICHIER%" "%BASE%"

if errorlevel 1 (
  echo.
  echo *** ECHEC de la sauvegarde. Lisez les messages ci-dessus. ***
) else (
  echo.
  echo Sauvegarde terminee : %FICHIER%
)

:fin
echo.
pause
endlocal
