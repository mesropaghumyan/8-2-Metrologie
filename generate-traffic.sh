#!/bin/bash

URL="http://localhost:8080"

echo "=== Générateur de trafic ==="

# Mode 1 : Déclencher l'alerte 5xx
if [ "$1" == "spike" ]; then
    echo "🔥 Génération d'un pic d'erreurs 500 (pour déclencher l'alerte TropErreurs5xx)..."
    # L'alerte se déclenche à > 10 erreurs en 5min. On en envoie 15.
    for i in {1..15}; do
        curl -s $URL/error > /dev/null
        echo -n "x "
        sleep 0.5
    done
    echo -e "\n✅ Pic de 15 erreurs 500 terminé. L'alerte apparaîtra dans Prometheus d'ici ~1 minute."
    exit 0
fi

# Mode 2 : Déclencher l'alerte Métier (Café)
if [ "$1" == "nocoffee" ]; then
    echo "🛑 Arrêt des commandes de café (pour déclencher l'alerte PlusDeCommandesDeCafe)..."
    echo "Le trafic continue (code 200), mais plus aucun café n'est commandé. (Ctrl+C pour arrêter)"
    while true; do
        curl -s $URL/success > /dev/null
        echo -n ". "
        sleep 2
    done
fi

# Mode 3 : Trafic standard pour peupler le Dashboard Grafana
echo "🚀 Génération de trafic standard pour Grafana (Ctrl+C pour arrêter)..."
while true; do
    # Générer un nombre aléatoire entre 1 et 100 pour répartir le trafic
    RAND=$(($RANDOM % 100))

    if [ $RAND -lt 60 ]; then
        curl -s $URL/success > /dev/null    # 60% de succès (2xx)
        echo -n "2 "
    elif [ $RAND -lt 85 ]; then
        curl -s $URL/order-coffee > /dev/null # 25% de commandes de café (2xx)
        echo -n "C "
    elif [ $RAND -lt 95 ]; then
        curl -s $URL/bad > /dev/null        # 10% de mauvaises requêtes (4xx)
        echo -n "4 "
    else
        curl -s $URL/error > /dev/null      # 5% d'erreurs internes (5xx)
        echo -n "5 "
    fi
    
    sleep 1
done