'use strict';

const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const { config } = require('../config');

const ISSUER = 'task-manager-api';

/**
 * Signs a short-lived access token.
 *
 * @param {string} userId
 * @param {{ expiresInSeconds?: number }} [options]
 * @returns {string}
 */
function signAccessToken(userId, options = {}) {
  return jwt.sign({ sub: userId, type: 'access' }, config.jwtAccessSecret, {
    algorithm: 'HS256',
    expiresIn: options.expiresInSeconds ?? config.accessTokenTtlSeconds,
    issuer: ISSUER,
  });
}

/**
 * Verifies an access token and returns its user id.
 *
 * @param {string} token
 * @returns {string} The user id (sub claim).
 * @throws {Error} When the token is invalid, expired, or not an access token.
 */
function verifyAccessToken(token) {
  const payload = jwt.verify(token, config.jwtAccessSecret, {
    algorithms: ['HS256'],
    issuer: ISSUER,
  });
  if (typeof payload !== 'object' || payload.type !== 'access' || typeof payload.sub !== 'string') {
    throw new Error('Invalid token type.');
  }
  return payload.sub;
}

/** @returns {string} A random, opaque refresh token (never stored in plain text). */
function generateRefreshToken() {
  return crypto.randomBytes(32).toString('base64url');
}

/**
 * @param {string} token
 * @returns {string} SHA-256 hash used to look the token up in the database.
 */
function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  hashRefreshToken,
};
