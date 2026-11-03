@echo off
REM ==================================================================
REM  GEO7531 - Activer les extensions de geomatique (Windows)
REM  Execute 02_installer_extensions.sql sur la base choisie avec psql.
REM  A lancer dans l'INVITE DE COMMANDES (cmd) ou par double-clic,
REM  depuis le dossier scripts.
REM  Modifiez les parametres ci-dessous avant de lancer.
REM ==================================================================
chcp 65001 >nul
setlocal

REM ---- Parametres a adapter ---------------------------------------
set PG_BIN=C:\Program Files\PostgreSQL\16\bin
set PGHOST=localhost
set PGPORT=5432
set PGUSER=postgres
REM Respectez la casse : GEO7531 et geo7531 sont deux bases differentes
set BASE=GEO7531
REM ------------------------------------------------------------------

set PGCLIENTENCODING=UTF8

if not exist "%PG_BIN%\psql.exe" (
  echo psql.exe introuvable dans "%PG_BIN%".
  echo Verifiez la ligne PG_BIN au debut de ce fichier.
  goto fin
)

echo.
echo Activation des extensions dans la base %BASE%...
echo Les blocs d'extensions non disponibles afficheront une erreur :
echo c'est normal, les autres seront quand meme activees.
echo.

REM Sans ON_ERROR_STOP : une extension manquante n'arrete pas le script
"%PG_BIN%\psql.exe" -d "%BASE%" -f "%~dp002_installer_extensions.sql"

:fin
echo.
pause
