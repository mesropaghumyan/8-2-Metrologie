#!/bin/bash
# Pipe le fichier CSV vers Logstash.
# Logstash (stdin input) se termine sur EOF → le Job Kubernetes se termine avec code 0.
set -e
echo "[air-quality-importer] Démarrage de l'import Air Quality..."
cat /data/Air_Quality.log | /usr/share/logstash/bin/logstash \
  -f /usr/share/logstash/pipeline/logstash.conf \
  --path.settings /usr/share/logstash/config
echo "[air-quality-importer] Import terminé."
