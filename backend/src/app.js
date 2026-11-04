'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { rateLimit } = require('express-rate-limit');
const { config } = require('./config');
const { HttpError } = require('./errors');
const { createAuthRouter } = require('./auth/routes');
const { createTaskRouter } = require('./tasks/routes');

/**
 * Builds the Express app. Options exist so tests can tighten limits without touching
 * global configuration.
 *
 * @param {{ authRateLimitMax?: number, authRateLimitWindowMs?: number }} [options]
 */
function createApp(options = {}) {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', false);
  app.use(helmet());
  // Mobile apps do not need CORS; browsers only get it for explicitly allowed origins.
  app.use(cors({ origin: config.corsOrigins.length > 0 ? config.corsOrigins : false }));
  // Bounded body size (OWASP API4: unrestricted resource consumption).
  app.use(express.json({ limit: '10kb' }));

  const sensitiveLimiter = rateLimit({
    windowMs: options.authRateLimitWindowMs ?? config.authRateLimitWindowMs,
    limit: options.authRateLimitMax ?? config.authRateLimitMax,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { error: 'Too many attempts. Try again later.' },
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/api/v1/auth', createAuthRouter({ sensitiveLimiter }));
  app.use('/api/v1/tasks', createTaskRouter());

  app.use((_req, _res, next) => {
    next(new HttpError(404, 'Not found.'));
  });

  // Central error handler: clients get a safe message, never a stack trace or SQL error.
  // eslint-disable-next-line no-unused-vars
  app.use((error, _req, res, _next) => {
    if (error instanceof HttpError) {
      return res.status(error.status).json({ error: error.message });
    }
    if (error && error.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Request body must be valid JSON.' });
    }
    if (error && error.type === 'entity.too.large') {
      return res.status(413).json({ error: 'Request body is too large.' });
    }
    if (!config.isTest) {
      console.error('Unexpected error:', error && error.message);
    }
    return res.status(500).json({ error: 'Something went wrong.' });
  });

  return app;
}

const app = createApp();

module.exports = { app, createApp };
