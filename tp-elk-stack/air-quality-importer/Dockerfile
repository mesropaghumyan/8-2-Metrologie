# Build context doit être tp-elk-stack/ (répertoire parent) :
#   docker build -t air-quality-importer:v1.0.0 -f air-quality-importer/Dockerfile .
#
# Le stdin input de Logstash se termine automatiquement sur EOF →
# le Job Kubernetes se termine proprement.

FROM docker.elastic.co/logstash/logstash:8.19.16

USER root
RUN mkdir -p /data

# Pipeline et settings personnalisés
COPY air-quality-importer/logstash.conf /usr/share/logstash/pipeline/logstash.conf
COPY air-quality-importer/logstash.yml  /usr/share/logstash/config/logstash.yml

# Dataset Air Quality embarqué dans l'image
COPY datasets/Air_Quality.log /data/Air_Quality.log

# Script d'entrée : pipe le fichier vers stdin de Logstash
COPY air-quality-importer/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R logstash:logstash \
         /usr/share/logstash/pipeline \
         /usr/share/logstash/config/logstash.yml \
         /data \
         /entrypoint.sh

USER logstash
ENTRYPOINT ["/entrypoint.sh"]
