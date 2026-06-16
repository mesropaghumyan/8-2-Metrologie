const express = require('express');
const client = require('prom-client');
const app = express();

const register = new client.Registry();

client.collectDefaultMetrics({ register });

// Métrique HTTP Globale : Compteur de requêtes
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Nombre total de requêtes HTTP',
  labelNames: ['method', 'route', 'status_code'],
});
register.registerMetric(httpRequestsTotal);

// Métrique Métier Spécifique
const coffeeServedTotal = new client.Counter({
  name: 'app_coffee_served_total',
  help: 'Nombre de cafés virtuels servis par l application',
  labelNames: ['type']
});
register.registerMetric(coffeeServedTotal);

// Middleware pour enregistrer automatiquement toutes les requêtes (sauf /metrics)
app.use((req, res, next) => {
  res.on('finish', () => {
    if (req.path !== '/metrics') {
      httpRequestsTotal.inc({ 
        method: req.method, 
        route: req.path, 
        status_code: res.statusCode 
      });
    }
  });
  next();
});

// Famille 2xx
app.get('/success', (req, res) => {
  res.status(200).send('Succès - Code 200\n');
});

// Famille 4xx
app.get('/bad', (req, res) => {
  res.status(400).send('Mauvaise requête - Code 400\n');
});

// Famille 5xx
app.get('/error', (req, res) => {
  res.status(500).send('Erreur interne - Code 500\n');
});

// Route métier
app.get('/order-coffee', (req, res) => {
  const types = ['espresso', 'latte', 'cappuccino'];
  const type = types[Math.floor(Math.random() * types.length)];
  coffeeServedTotal.inc({ type });
  res.status(200).send(`Un ${type} a été commandé !\n`);
});

// --- EXPOSITION DES METRIQUES ---
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(8080, () => {
  console.log('Application instrumentée démarrée sur le port 8080');
});