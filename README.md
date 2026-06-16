# INFRES17 — Génie Logiciel · Métrologie

**Auteur :** Mesrop Aghumyan  
**Cours :** INFRES17 8.2 — Génie Logiciel, module Métrologie  
**Semestre :** S8

Ce dépôt contient les deux TPs du module Métrologie. Chaque TP est autonome, avec ses propres manifests Kubernetes, son application et sa documentation.

---

## Sommaire

| TP | Sujet | Dossier |
|---|---|---|
| TP 1 | Observabilité avec Prometheus & Grafana | [`tp-prometheus-grafana/`](tp-prometheus-grafana/) |
| TP 2 | Centralisation des logs avec la stack ELK | [`tp-elk-stack/`](tp-elk-stack/) |

---

## Structure du dépôt

```
.
├── README.md                    ← ce fichier
├── tp-prometheus-grafana/
│   ├── README.md                ← procédure complète TP1
│   ├── TP_PROMETHEUS_GRAFANA.md ← sujet du TP1
│   ├── kind-config.yaml
│   ├── generate-traffic.sh
│   ├── app/                     ← application Node.js instrumentée (prom-client)
│   ├── grafana/                 ← dashboard.json Grafana
│   └── manifests/               ← Prometheus, Grafana, Alertmanager, app...
└── tp-elk-stack/
    ├── README.md                ← procédure complète TP2
    ├── TP_ELK.md                ← sujet du TP2
    ├── kind-config.yaml
    ├── generate-traffic.sh
    ├── app/                     ← application Node.js avec logs JSON (pino)
    ├── air-quality-importer/    ← image Logstash pour import CSV Air Quality
    ├── datasets/                ← Air_Quality.log
    ├── manifests/               ← Elasticsearch, Kibana, Logstash, Filebeat, app...
    └── kibana/                  ← dashboards.ndjson + scripts import/export
```

---

## Prérequis communs

- [kind](https://kind.sigs.k8s.io/) ≥ 0.20
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — allouer **≥ 4 Go** pour le TP1, **≥ 6 Go** pour le TP2
- `curl`, `bash`

> Les deux TPs utilisent des clusters kind distincts (`tp-monitoring` et `tp-elk`). Ils peuvent coexister, mais cela demande ≥ 10 Go de RAM au total. Il est recommandé de ne faire tourner qu'un seul cluster à la fois.

---

## TP 1 — Prometheus & Grafana

**Objectif :** déployer une stack d'observabilité complète (Prometheus, Alertmanager, Grafana, Node-Exporter, Kube-State-Metrics) et une application HTTP instrumentée avec des métriques custom.

**Accès rapide :**
```bash
cd tp-prometheus-grafana/
kind create cluster --config kind-config.yaml
docker build -t instrumented-app:v1.0.0 ./app
kind load docker-image instrumented-app:v1.0.0 --name tp-monitoring
kubectl apply -f manifests/
```

- Application : http://localhost:30000  
- Grafana : http://localhost:30001 (admin / admin)

→ Documentation complète : [tp-prometheus-grafana/README.md](tp-prometheus-grafana/README.md)

---

## TP 2 — Stack ELK

**Objectif :** déployer Elasticsearch, Kibana, Logstash et Filebeat dans Kubernetes, collecter les logs d'une application HTTP, et créer des dashboards Kibana pour l'investigation et le support.

**Accès rapide :**
```bash
cd tp-elk-stack/
kind create cluster --config kind-config.yaml
docker build -t coffee-app:v1.0.0 ./app
kind load docker-image coffee-app:v1.0.0 --name tp-elk
docker build -t air-quality-importer:v1.0.0 -f air-quality-importer/Dockerfile .
kind load docker-image air-quality-importer:v1.0.0 --name tp-elk
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-elasticsearch.yaml
kubectl apply -f manifests/02-kibana.yaml
kubectl apply -f manifests/03-logstash.yaml
kubectl apply -f manifests/04-filebeat.yaml
kubectl apply -f manifests/05-app.yaml
# Attendre que tous les pods soient Ready, puis :
./kibana/setup-kibana.sh && ./kibana/import-kibana.sh
```

- Application : http://localhost:30000  
- Kibana : http://localhost:30001

→ Documentation complète : [tp-elk-stack/README.md](tp-elk-stack/README.md)

---

## Conventions du dépôt

- Les manifests Kubernetes sont écrits manuellement, sans Helm ni Operator.
- Les images locales sont taguées avec une version figée (`v1.0.0`) et chargées dans kind via `kind load docker-image`.
- Le namespace utilisé est `monitoring` pour le TP1 et `elk` pour le TP2.
- Aucune donnée sensible n'est présente dans les logs applicatifs ni dans les fichiers sources.

---

## Nettoyage

```bash
# Supprimer le cluster TP1
kind delete cluster --name tp-monitoring

# Supprimer le cluster TP2
kind delete cluster --name tp-elk
```
