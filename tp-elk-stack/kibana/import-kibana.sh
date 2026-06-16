#!/bin/bash
# Importe les saved objects depuis kibana/dashboards.ndjson.
# Utiliser après un déploiement frais pour restaurer les dashboards.

KIBANA_URL="http://localhost:30001"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$SCRIPT_DIR/dashboards.ndjson"

if [ ! -f "$INPUT" ]; then
  echo "Fichier $INPUT introuvable."
  echo "Lancez d'abord setup-kibana.sh et export-kibana.sh."
  exit 1
fi

echo "Import des saved objects depuis $INPUT..."

curl -sf -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form file=@"$INPUT" | python3 -m json.tool

echo "Import terminé."
