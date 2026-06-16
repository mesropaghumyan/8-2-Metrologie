#!/bin/bash
# Crée les Data Views et les Saved Searches via l'API Kibana.
# À lancer APRÈS que Kibana soit prêt (http://localhost:30001).
# Ensuite : créez les dashboards manuellement dans Kibana,
# puis lancez export-kibana.sh pour générer dashboards.ndjson.

KIBANA_URL="http://localhost:30001"

echo "=== Configuration automatique de Kibana ==="

# Attendre que Kibana soit disponible
echo -n "Attente de Kibana"
until curl -sf "$KIBANA_URL/api/status" | grep -q '"level":"available"' 2>/dev/null; do
  echo -n "."
  sleep 5
done
echo " OK"

# ── Data View : app-logs-* ───────────────────────────────────────────────────
echo "Création de la Data View app-logs-*..."
curl -sf -X POST "$KIBANA_URL/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "data_view": {
      "title": "app-logs-*",
      "timeFieldName": "@timestamp",
      "name": "App Logs"
    }
  }' | python3 -m json.tool 2>/dev/null || echo "(déjà existante ou erreur)"

# ── Data View : air-quality-* ────────────────────────────────────────────────
echo "Création de la Data View air-quality-*..."
curl -sf -X POST "$KIBANA_URL/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "data_view": {
      "title": "air-quality-*",
      "timeFieldName": "@timestamp",
      "name": "Air Quality"
    }
  }' | python3 -m json.tool 2>/dev/null || echo "(déjà existante ou erreur)"

# ── Saved Search : erreurs app ───────────────────────────────────────────────
echo "Création de la Saved Search 'Erreurs application'..."
curl -sf -X POST "$KIBANA_URL/api/saved_objects/search" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "Erreurs application (4xx + 5xx)",
      "description": "Tous les logs avec status_code >= 400",
      "columns": ["level","route","status_code","duration_ms","error_reason","message"],
      "sort": [["@timestamp","desc"]],
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"query\":{\"query\":\"status_code >= 400\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
      }
    },
    "references": [
      { "id": "app-logs-*", "name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern" }
    ]
  }' | python3 -m json.tool 2>/dev/null || echo "(erreur ou déjà existante)"

echo ""
echo "=== Kibana configuré ==="
echo "Accès Kibana : $KIBANA_URL"
echo ""
echo "Étapes suivantes :"
echo "  1. Ouvrir Kibana > Analytics > Discover"
echo "  2. Sélectionner la Data View 'App Logs' et explorer les logs"
echo "  3. Créer les dashboards Développeur et Support manuellement"
echo "  4. Lancer ./export-kibana.sh pour sauvegarder les dashboards"
