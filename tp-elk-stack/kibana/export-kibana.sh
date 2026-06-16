#!/bin/bash
# Exporte TOUS les saved objects Kibana (dashboards, visualisations, data views...)
# dans kibana/dashboards.ndjson.
# À lancer après avoir créé vos dashboards manuellement dans Kibana.

KIBANA_URL="http://localhost:30001"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/dashboards.ndjson"

echo "Export des saved objects Kibana vers $OUTPUT..."

curl -sf -X POST "$KIBANA_URL/api/saved_objects/_export" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "type": ["dashboard", "visualization", "lens", "index-pattern", "search"],
    "includeReferencesDeep": true
  }' > "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
echo "Export terminé : $LINES objets dans $OUTPUT"
