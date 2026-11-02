#!/usr/bin/env bash
# ============================================================
#  GEO7531 - Restauration d'une base PostgreSQL/PostGIS (macOS / Linux)
#  Usage : ./restauration.sh fichier.backup nom_nouvelle_base
#  La base cible est CRÉÉE par le script : elle ne doit pas exister.
# ============================================================
set -euo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"

FICHIER="${1:-}"
BASE="${2:-}"
[[ -z "$FICHIER" ]] && read -rp "Chemin du fichier .backup : " FICHIER
[[ -z "$BASE" ]] && read -rp "Nom de la NOUVELLE base à créer : " BASE

[[ -f "$FICHIER" ]] || { echo "Fichier introuvable : $FICHIER"; exit 1; }
command -v pg_restore >/dev/null || { echo "pg_restore introuvable (voir PATH)."; exit 1; }

CONN=(-h "$PGHOST" -p "$PGPORT" -U "$PGUSER")

echo "[1/3] Création de la base « $BASE »..."
createdb "${CONN[@]}" -E UTF8 "$BASE"

echo "[2/3] Activation de PostGIS..."
psql "${CONN[@]}" -d "$BASE" -c "CREATE EXTENSION IF NOT EXISTS postgis;" \
  || echo "(PostGIS non disponible : on continue sans.)"

echo "[3/3] Restauration de « $FICHIER »..."
if pg_restore "${CONN[@]}" -d "$BASE" --no-owner --no-privileges --single-transaction -v "$FICHIER"; then
  echo "Restauration terminée dans « $BASE ». Dans pgAdmin : clic droit sur Databases > Refresh."
else
  echo "*** Échec : aucune donnée importée. Voir « Problèmes fréquents » dans le README. ***"
  exit 1
fi
