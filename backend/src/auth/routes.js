'use strict';

const express = require('express');
const { badRequestOnTypeError } = require('../errors');
const { authenticate } = require('../middleware/authenticate');
const { validateEmail, validatePassword } = require('./validation');
const service = require('./service');

/**
 * @param {{ sensitiveLimiter: import('express').RequestHandler }} deps
 */
function createAuthRouter({ sensitiveLimiter }) {
  const router = express.Router();

  router.post('/register', sensitiveLimiter, async (req, res) => {
    const body = req.body ?? {};
    const email = badRequestOnTypeError(() => validateEmail(body.email));
    const password = badRequestOnTypeError(() => validatePassword(body.password));
    res.status(201).json(await service.register(email, password));
  });

  router.post('/login', sensitiveLimiter, async (req, res) => {
    const body = req.body ?? {};
    const email = badRequestOnTypeError(() => validateEmail(body.email));
    const password = badRequestOnTypeError(() => validatePassword(body.password));
    res.json(await service.login(email, password));
  });

  router.post('/refresh', sensitiveLimiter, async (req, res) => {
    res.json(await service.refresh(req.body?.refreshToken));
  });

  router.post('/logout', async (req, res) => {
    await service.logout(req.body?.refreshToken);
    res.status(204).end();
  });

  router.post('/logout-all', authenticate, async (req, res) => {
    await service.logoutAll(req.userId);
    res.status(204).end();
  });

  return router;
}

module.exports = { createAuthRouter };
