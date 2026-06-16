const express = require('express');
const pino = require('pino');
const crypto = require('crypto');

// Logger structuré JSON — chaque ligne est un objet JSON parsable par Logstash
const logger = pino({
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: {
    level: (label) => ({ level: label }),
    // Supprime pid et hostname des bindings par défaut
    bindings: () => ({}),
  },
  messageKey: 'message',
});

const app = express();
app.use(express.json());

// ─────────────────────────────────────────────
// Middleware : log structuré de chaque requête
// ─────────────────────────────────────────────
app.use((req, res, next) => {
  const requestId = crypto.randomUUID();
  const startTime = Date.now();
  req.requestId = requestId;
  // Champs métier additionnels attachables par les routes
  req.logFields = {};

  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const level =
      res.statusCode >= 500 ? 'error' :
      res.statusCode >= 400 ? 'warn' :
      'info';

    logger[level]({
      request_id: requestId,
      method:     req.method,
      route:      req.path,
      status_code: res.statusCode,
      duration_ms: duration,
      ...req.logFields,
    }, `${req.method} ${req.path} ${res.statusCode}`);
  });

  next();
});

// ─────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────

// 2xx — trafic nominal
app.get('/success', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Succès' });
});

// 4xx — erreur client simulée
app.get('/bad', (req, res) => {
  req.logFields.error_reason = 'bad_request';
  res.status(400).json({ status: 'error', message: 'Mauvaise requête' });
});

// 5xx — erreur serveur simulée
app.get('/error', (req, res) => {
  req.logFields.error_reason = 'internal_server_error';
  res.status(500).json({ status: 'error', message: 'Erreur interne simulée' });
});

// Route métier : commande de café (comportement propre à l'application)
app.get('/order-coffee', (req, res) => {
  const types = ['espresso', 'latte', 'cappuccino'];
  const type = types[Math.floor(Math.random() * types.length)];
  req.logFields.coffee_type = type;
  res.status(200).json({ status: 'ok', coffee: type });
});

// Health check (non loggué en production via filter, conservé ici pour la simplicité)
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// 404 pour toute route inconnue
app.use((req, res) => {
  req.logFields.error_reason = 'not_found';
  res.status(404).json({ status: 'error', message: 'Route inconnue' });
});

// ─────────────────────────────────────────────
// Démarrage
// ─────────────────────────────────────────────
const PORT = 8080;
app.listen(PORT, () => {
  logger.info({ service: 'coffee-app', port: PORT }, 'Application coffee-app démarrée sur le port 8080');
});
