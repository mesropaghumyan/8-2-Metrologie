#!/bin/bash
# Générateur de trafic pour le TP ELK
# Cible l'application coffee-app exposée sur NodePort 30000

URL="http://localhost:30000"

echo "=== Générateur de trafic ELK ==="

# Mode 1 : Spike d'erreurs 5xx (pour observer dans Kibana)
if [ "$1" == "spike" ]; then
    echo "Génération d'un pic d'erreurs 500..."
    for i in {1..20}; do
        curl -s "$URL/error" > /dev/null
        echo -n "x "
        sleep 0.3
    done
    echo -e "\nPic de 20 erreurs 500 terminé. Observez dans Kibana > app-logs-*"
    exit 0
fi

# Mode 2 : Erreurs 4xx uniquement
if [ "$1" == "bad" ]; then
    echo "Génération d'erreurs 400..."
    for i in {1..10}; do
        curl -s "$URL/bad" > /dev/null
        echo -n "4 "
        sleep 0.5
    done
    echo -e "\n10 erreurs 400 terminées."
    exit 0
fi

# Mode 3 : Requête unique avec request_id visible
if [ "$1" == "trace" ]; then
    echo "Envoi d'une requête tracée sur /order-coffee..."
    curl -v "$URL/order-coffee" 2>&1 | grep -E "< HTTP|coffee"
    echo "Cherchez ce request_id dans Kibana : Discover > app-logs-* > champ request_id"
    exit 0
fi

# Mode 4 : Trafic standard continu pour alimenter les dashboards
echo "Génération de trafic standard (Ctrl+C pour arrêter)..."
echo "  2=success, C=coffee, 4=bad request, 5=server error"
while true; do
    RAND=$(($RANDOM % 100))

    if [ $RAND -lt 60 ]; then
        curl -s "$URL/success" > /dev/null
        echo -n "2 "
    elif [ $RAND -lt 85 ]; then
        curl -s "$URL/order-coffee" > /dev/null
        echo -n "C "
    elif [ $RAND -lt 95 ]; then
        curl -s "$URL/bad" > /dev/null
        echo -n "4 "
    else
        curl -s "$URL/error" > /dev/null
        echo -n "5 "
    fi

    sleep 1
done
