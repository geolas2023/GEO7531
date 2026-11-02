#!/usr/bin/env bash
# ============================================================
#  GEO7531 - Sauvegarde d'une base PostgreSQL/PostGIS (macOS / Linux)
#  Usage : ./sauvegarde.sh nom_de_la_base
# ============================================================
set -euo pipefail

# ---- Paramètres à adapter ---------------------------------
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
DOSSIER="${DOSSIER:-$HOME/GEO7531/sauvegardes}"
# -----------------------------------------------------------

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  read -rp "Nom de la base à sauvegarder : " BASE
fi
[[ -z "$BASE" ]] && { echo "Aucun nom de base fourni."; exit 1; }

command -v pg_dump >/dev/null || {
  echo "pg_dump introuvable. Ajoutez le dossier bin de PostgreSQL au PATH."
  echo "  macOS (Postgres.app) : /Applications/Postgres.app/Contents/Versions/latest/bin"
  exit 1
}

mkdir -p "$DOSSIER"
FICHIER="$DOSSIER/${BASE}_$(date +%Y%m%d_%H%M).backup"

echo "Sauvegarde de « $BASE » vers : $FICHIER"
pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -F c -E UTF8 -v -f "$FICHIER" "$BASE"

echo "Sauvegarde terminée : $FICHIER ($(du -h "$FICHIER" | cut -f1))"
