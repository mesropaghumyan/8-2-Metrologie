# Rendu TP - Observabilité K8s (Prometheus & Grafana)

Ce dépôt contient l'ensemble des ressources nécessaires pour déployer une stack d'observabilité complète (Prometheus, Alertmanager, Grafana, Node-Exporter, Kube-State-Metrics) ainsi qu'une application instrumentée personnalisée, le tout déployé "from scratch" via des manifests Kubernetes purs (sans Helm ni Prometheus Operator).

## 1. Création du cluster local

Avant toute manipulation ou compilation d'image, il est impératif de créer le cluster Kubernetes local avec `kind` en utilisant le fichier de configuration fourni.

```bash
kind create cluster --config kind-config.yaml
```

## 2. Procédure de construction de l'image de l'application

Une fois le cluster opérationnel, l'application doit être compilée localement puis injectée directement dans les nœuds du cluster `kind` (car Kubernetes n'a pas accès aux images locales de l'hôte Docker par défaut).

```bash
# 1. Se placer dans le dossier de l'application
cd app/

# 2. Construire l'image Docker avec un tag figé
docker build -t instrumented-app:v1.0.0 .

# 3. Charger l'image dans le cluster kind local
kind load docker-image instrumented-app:v1.0.0 --name tp-monitoring

# 4. Revenir à la racine du projet
cd ..
```

## 3. Procédure de déploiement

Maintenant que le cluster tourne et qu'il possède l'image de l'application, nous pouvons appliquer tous les manifests Kubernetes en une seule commande :

```bash
kubectl apply -f manifests/
```

Vérifier que tous les pods sont opérationnels avant de continuer :

```bash
kubectl get pods -n monitoring
```

## 4. Procédure d'accès aux interfaces

Pour accéder aux différents services depuis la machine hôte, nous utilisons des tunnels (`port-forward`). Il est conseillé d'ouvrir un terminal pour chaque commande et de les laisser tourner en arrière-plan.

- Application HTTP : kubectl port-forward svc/instrumented-app -n monitoring 8080:8080
    - Accès : http://localhost:8080
- Accès : http://localhost:8080
    - Accès : http://localhost:8080
- Grafana : kubectl port-forward svc/grafana -n monitoring 3000:80
    - Accès : http://localhost:3000
    - Identifiants par défaut : admin / admin

## 5. Choix d'instrumentation de l'application

L'application est une API Node.js/Express instrumentée avec la librairie prom-client. Elle simule la prise de commande d'une boutique de café virtuelle.

- Métrique globale HTTP : Un compteur `http_requests_total` a été mis en place via un middleware pour intercepter toutes les requêtes. Il possède les labels `method`, `route`, et `status_code` pour différencier facilement les familles 2xx, 4xx et 5xx.

- Métrique métier personnalisée : Un compteur `app_coffee_served_total` doté du label `type` (espresso, latte, cappuccino) s'incrémente lors d'un appel à la route `/order-coffee`.

Les métriques sont exposées sur la route `/metrics` et automatiquement collectées par Prometheus grâce aux annotations Kubernetes (Service Discovery) : prometheus.io/scrape: `"true"`.

## 6. Méthode de génération de trafic

Un script bash (`generate-traffic.sh`) est fourni à la racine pour simuler un comportement utilisateur reproductible et alimenter les métriques.

Rendre le script exécutable avec `chmod +x generate-traffic.sh` avant de l'utiliser.

- Trafic de base (pour peupler Grafana) : `./generate-traffic.sh` (génère un mix aléatoire de réponses 2xx, 4xx, 5xx et de commandes de café en boucle).

- Test Pic d'erreurs 5xx : `./generate-traffic.sh spike` (envoie instantanément 15 erreurs 500 pour tester l'alerte correspondante).

- Test Panne Métier : `./generate-traffic.sh nocoffee` (génère du trafic HTTP valide, mais n'appelle plus la route des commandes de café pour tester l'alerte métier).

## 7. Alertes et Justification du seuil X

Le seuil X choisi pour le déclenchement de l'alerte des erreurs 5xx est de 10 erreurs sur une fenêtre de 5 minutes. Dans le cadre d'un microservice (ou d'un environnement de TP où l'on souhaite une validation rapide), 10 erreurs internes en 5 minutes révèlent une instabilité avérée du service qui nécessite l'intervention d'un SRE, tout en laissant une infime marge pour tolérer un glitch réseau isolé.

Voici comment reproduire le déclenchement des 4 alertes exigées (visibles dans l'onglet Alerts de Prometheus) :

1. Alerte 1 - Composant obligatoire indisponible (ComposantIndisponible) : Pour simuler l'indisponibilité de la collecte d'un composant sans le supprimer du cluster (ce qui fausserait le test), nous modifions son annotation de port vers un port inexistant.
    - `kubectl annotate svc kube-state-metrics -n monitoring prometheus.io/port="9999" --overwrite`
    - La métrique `up` passe à 0, l'alerte se déclenche au bout d'une minute.
2. Alerte 2 - Trop d'erreurs 5xx (TropErreurs5xx) :
    - Lancer le script avec l'argument dédié : `./generate-traffic.sh spike`.
    - Cela génère 15 erreurs (dépassant le seuil X=10) ; l'alerte se déclenche en moins d'une minute.
3. Alerte 3 - Alertmanager indisponible (AlertmanagerK8sIndisponible) :
    - Mise à zéro des réplicas d'Alertmanager pour simuler un crash du pod : `kubectl scale deployment alertmanager -n monitoring --replicas=0`.
    - La règle interrogeant `kube-state-metrics` détecte l'absence de réplica disponible, l'alerte se déclenche.
4. Alerte 4 - Alerte métier propre à l'application (PlusDeCommandesDeCafe) :
    - Lancer le script avec l'argument dédié : `./generate-traffic.sh nocoffee`.
    - Après 5 minutes sans aucune incrémentation du compteur métier `app_coffee_served_total`, l'alerte se déclenche pour signaler une panne fonctionnelle du parcours utilisateur.

## 8. Requêtes PromQL principales

Dans les alertes (fichier `01-prometheus.yaml`)
- Alerte 1 : `up == 0`
- Alerte 2 : `sum by (kubernetes_name) (increase(http_requests_total{status_code=~"5.."}[5m])) > 10`
- Alerte 3 : `kube_deployment_status_replicas_available{deployment="alertmanager"} == 0`
- Alerte 4 : `sum(increase(app_coffee_served_total[5m])) == 0`

Dans le Dashboard Grafana (fichier dashboard.json)
- Panel A (5xx sur 5 min) : `sum(increase(http_requests_total{status_code=~"5.."}[5m]))`
- Panel B (4xx et 5xx séparés) : `sum by (status_code) (increase(http_requests_total{status_code=~"[45].."}[5m]))`
- Panel C (Évolution temporelle) : `sum by (status_code) (rate(http_requests_total[1m]))`
- Panel D (Répartition totale) : `sum by (status_code) (increase(http_requests_total[5m]))` (formaté en % via les options visuelles de Grafana).
- Panel E (Cafés par type) : `sum by (type) (increase(app_coffee_served_total[5m]))`

## 9. Hypothèses et limites éventuelles

- Stockage éphémère : Pour garder des manifests simples et lisibles comme demandé, aucun `PersistentVolumeClaim` n'a été configuré. Si les Pods Prometheus ou Grafana sont recréés, l'historique de la TSDB et les modifications manuelles non exportées seront perdus.

- Provisioning des Dashboards : Le chargement automatique du `dashboard.json` dans Grafana n'a pas été scripté via un `ConfigMap`/`Sidecar` pour respecter la simplicité requise par le TP (uniquement du provisioning de `Datasource`). L'import doit se faire manuellement via l'interface.

- Réception des alertes : `Alertmanager` est bien configuré et reçoit les alertes de `Prometheus`. Cependant, le "receiver" est un mock (dummy) par défaut. Les alertes ne sont donc pas véritablement expédiées vers un canal de communication externe (Slack, Mail), ce qui reste hors du périmètre de ce TP d'infrastructure.