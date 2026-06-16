# TP ELK Stack — Coffee App

Stack ELK déployée sur Kubernetes (kind) pour l'observation des logs d'une application HTTP.  
Auteur : Mesrop Aghumyan

---

## Arborescence

```
tp-elk-stack/
  README.md
  kind-config.yaml
  generate-traffic.sh
  app/                        ← application HTTP Node.js avec logs JSON (pino)
  air-quality-importer/       ← image Logstash custom pour importer Air_Quality.log
  datasets/                   ← Air_Quality.log
  manifests/                  ← manifests Kubernetes (namespace, ES, Kibana, Logstash, Filebeat, app, job)
  kibana/                     ← dashboards.ndjson + scripts d'import/export
```

---

## Composants déployés

| Composant | Image | Rôle |
|---|---|---|
| Elasticsearch | `docker.elastic.co/elasticsearch/elasticsearch:8.19.16` | Stockage et indexation des logs |
| Kibana | `docker.elastic.co/kibana/kibana:8.19.16` | Visualisation et dashboards |
| Logstash | `docker.elastic.co/logstash/logstash:8.19.16` | Transformation et routage des logs |
| Filebeat | `docker.elastic.co/beats/filebeat:8.19.16` | Collecte des logs des pods Kubernetes |
| coffee-app | `coffee-app:v1.0.0` (build local) | Application HTTP avec logs structurés JSON |
| air-quality-importer | `air-quality-importer:v1.0.0` (build local, base logstash:8.19.16) | Import CSV Air Quality via Job Kubernetes |

---

## Prérequis

- [kind](https://kind.sigs.k8s.io/) ≥ 0.20
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) avec **≥ 6 Go de RAM alloués**
- `curl`, `bash`, `python3` (pour `setup-kibana.sh`)

---

## 1. Déploiement complet (cluster vierge)

### Créer le cluster kind

```bash
cd tp-elk-stack/
kind create cluster --config kind-config.yaml
```

Le cluster s'appelle `tp-elk`. Les ports NodePort utilisés sont :
- `30000` → application coffee-app
- `30001` → Kibana

### Construire et charger les images dans kind

```bash
# Application HTTP
docker build -t coffee-app:v1.0.0 ./app
kind load docker-image coffee-app:v1.0.0 --name tp-elk

# Importeur Air Quality (contexte = tp-elk-stack/ car il embarque datasets/)
docker build -t air-quality-importer:v1.0.0 -f air-quality-importer/Dockerfile .
kind load docker-image air-quality-importer:v1.0.0 --name tp-elk
```

### Déployer les manifests dans l'ordre

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-elasticsearch.yaml
kubectl apply -f manifests/02-kibana.yaml
kubectl apply -f manifests/03-logstash.yaml
kubectl apply -f manifests/04-filebeat.yaml
kubectl apply -f manifests/05-app.yaml
```

### Attendre que tous les pods soient prêts (≈ 3-5 min)

```bash
kubectl get pods -n elk -w
```

Tous les pods doivent être `Running` avec `READY 1/1` (ou `Running` pour le DaemonSet Filebeat).

---

## 2. Accès aux services

| Service | URL |
|---|---|
| Application coffee-app | http://localhost:30000 |
| Kibana | http://localhost:30001 |

Port-forward Elasticsearch si besoin (débogage) :
```bash
kubectl port-forward -n elk svc/elasticsearch 9200:9200
# puis : curl http://localhost:9200/_cluster/health
```

---

## 3. Import du dataset Air Quality

L'import est reproductible depuis les sources via un Job Kubernetes :

```bash
kubectl apply -f manifests/06-air-quality-importer-job.yaml

# Suivre l'avancement (des points s'affichent, un par document)
kubectl logs -n elk -l job-name=air-quality-importer -f
```

Le Job pipe `Air_Quality.log` via stdin vers Logstash, qui parse chaque ligne en CSV et indexe dans `air-quality-YYYY.MM.dd`.

Pour relancer l'import (par ex. après reset) :
```bash
kubectl delete job -n elk air-quality-importer
kubectl apply -f manifests/06-air-quality-importer-job.yaml
```

---

## 4. Configuration de Kibana (Data Views + Saved Search)

```bash
chmod +x kibana/setup-kibana.sh kibana/import-kibana.sh
./kibana/setup-kibana.sh    # crée les Data Views app-logs-* et air-quality-*
./kibana/import-kibana.sh   # importe les 3 dashboards + 13 visualisations
```

`setup-kibana.sh` attend automatiquement que Kibana soit disponible.

**Note** : après `import-kibana.sh`, ajouter manuellement le contrôle interactif dans le Air Quality Dashboard :  
`Controls → Add control → Options list → Field: geo_place_name → Label: Location`

---

## 5. Génération des logs (scénarios de validation)

```bash
chmod +x generate-traffic.sh

# Trafic standard continu : mix 60% succès / 25% café / 10% 4xx / 5% 5xx
./generate-traffic.sh

# Spike de 20 erreurs 500 (pour tester le dashboard développeur)
./generate-traffic.sh spike

# 10 erreurs 400 (erreurs client)
./generate-traffic.sh bad

# Requête unique tracée — affiche le request_id à rechercher dans Kibana
./generate-traffic.sh trace
```

Routes disponibles :

| Route | Code | Comportement |
|---|---|---|
| `GET /success` | 200 | Trafic nominal |
| `GET /order-coffee` | 200 | Route métier — log avec `coffee_type` |
| `GET /bad` | 400 | Erreur client simulée |
| `GET /error` | 500 | Erreur serveur simulée |
| `GET /health` | 200 | Health check |
| `GET /*` | 404 | Route inconnue |

---

## 6. Structure des logs applicatifs

L'application utilise **pino** et écrit un objet JSON par ligne sur `stdout`.  
Filebeat collecte ces lignes depuis `/var/log/containers/coffee-app-*.log`, les envoie à Logstash qui parse le JSON et indexe dans `app-logs-*`.

Exemple de log nominal :
```json
{
  "level": "info",
  "time": "2026-06-16T10:00:00.123Z",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "method": "GET",
  "route": "/order-coffee",
  "status_code": 200,
  "duration_ms": 4,
  "coffee_type": "latte",
  "message": "GET /order-coffee 200"
}
```

Exemple de log d'erreur :
```json
{
  "level": "error",
  "time": "2026-06-16T10:00:01.456Z",
  "request_id": "7b12f3a0-1234-5678-abcd-ef0123456789",
  "method": "GET",
  "route": "/error",
  "status_code": 500,
  "duration_ms": 2,
  "error_reason": "internal_server_error",
  "message": "GET /error 500"
}
```

| Champ | Type | Description |
|---|---|---|
| `level` | string | `info` (2xx), `warn` (4xx), `error` (5xx) |
| `time` → `@timestamp` | ISO8601 | Horodatage de fin de requête |
| `request_id` | UUID v4 | Identifiant unique par requête |
| `method` | string | Verbe HTTP |
| `route` | string | Chemin de la requête |
| `status_code` | integer | Code HTTP de la réponse |
| `duration_ms` | integer | Durée de traitement en millisecondes |
| `coffee_type` | string | Type de café (uniquement sur `/order-coffee`) |
| `error_reason` | string | Cause de l'erreur (uniquement sur 4xx/5xx) |

Les données sensibles ne sont jamais loggées.

---

## 7. Recherches Kibana principales

Dans **Analytics → Discover**, Data View `app-logs-*` :

| Objectif | KQL |
|---|---|
| Toutes les erreurs | `status_code >= 400` |
| Erreurs serveur uniquement | `status_code >= 500` |
| Erreurs client uniquement | `status_code: 400` |
| Par niveau de log | `level: "error"` |
| Par route | `route: "/order-coffee"` |
| Par identifiant de requête | `request_id: "votre-uuid"` |
| Route + erreur | `route: "/bad" AND level: "warn"` |
| Pics sur une fenêtre | `status_code >= 500` + régler la fenêtre temporelle |

Dans **Analytics → Discover**, Data View `air-quality-*` (fenêtre 2008–2014) :

| Objectif | KQL |
|---|---|
| Pics de pollution SO2 | `name: "Sulfur Dioxide (SO2)" AND data_value > 10` |
| Ozone en été | `name: "Ozone (O3)" AND time_period: "Summer*"` |
| Pollution > seuil sur période | `data_value > 10 AND @timestamp >= "2010-01-01"` |
| Filtrer sur Bronx | `geo_place_name: "Bronx"` |

---

## 8. Description des dashboards

### Developer Dashboard (`app-logs-*`)

Destiné à un développeur qui investigue un incident. Répond aux questions :
- **Quand** les erreurs ont commencé → histogramme des niveaux de log dans le temps
- **Quelles routes** sont concernées → bar chart horizontal des top routes en erreur
- **Quelle répartition** des status codes → pie chart
- **Quelle durée** par route → bar chart `Average(duration_ms)`
- **Détail** par combinaison level/route/status → tableau trié par fréquence

### Support Dashboard (`app-logs-*`)

Destiné au support ou à un profil non technique. Lisible sans connaître l'implémentation :
- **Volume de trafic** global dans le temps → area chart
- **Nombre total de requêtes** → metric card
- **Nombre d'erreurs** (4xx + 5xx) → metric card
- **Cafés commandés** (KPI métier) → metric card
- **Répartition succès/avertissements/erreurs** → pie chart par `level`

### Air Quality Dashboard (`air-quality-*`)

Données qualité de l'air New York 2008–2014 :
- **Évolution temporelle** : `Average(data_value)` par polluant → line chart
- **Comparaison période × polluant** : heatmap `time_period` × `name`
- **Top records de pollution** : table triée par `data_value` décroissant (lieu, polluant, période, valeur)
- **Contrôle interactif** : Options list sur `geo_place_name` (filtrer sur Bronx, Brooklyn, etc.)

---

## 9. Exporter les dashboards après modification

```bash
./kibana/export-kibana.sh   # écrase kibana/dashboards.ndjson
```

Pour restaurer sur un cluster vierge :
```bash
./kibana/setup-kibana.sh
./kibana/import-kibana.sh
```

---

## 10. Supprimer le cluster

```bash
kind delete cluster --name tp-elk
```

---

## Hypothèses et limites

- **Persistance** : Elasticsearch utilise `emptyDir`. Les données sont perdues si le pod redémarre. Pour un usage durable, remplacer par un `PersistentVolumeClaim`.
- **Sécurité** : `xpack.security.enabled: false`. Adapté uniquement à un environnement local de TP.
- **Ordre de démarrage** : l'import Air Quality doit être lancé après qu'Elasticsearch soit `Ready`. Le Job réessaie automatiquement (`backoffLimit: 3`).
- **Ressources** : les images Elastic `8.19.16` font ~1 Go chacune. Le `kind load` initial peut prendre 2-3 min par image. Docker Desktop doit avoir ≥ 6 Go de RAM alloués.
- **Filebeat** : collecte uniquement les logs des containers `coffee-app-*` via le pattern `/var/log/containers/coffee-app-*.log`. Les logs techniques de la stack ELK ne sont pas ingérés dans `app-logs-*`.
