'use strict';

require('dotenv').config();

const isTest = process.env.NODE_ENV === 'test';

/**
 * Reads a positive integer from the environment.
 *
 * @param {string} name - Variable name.
 * @param {number} fallback - Value used when the variable is missing or invalid.
 * @returns {number}
 */
function intFromEnv(name, fallback) {
  const parsed = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

const config = {
  port: intFromEnv('PORT', 3000),
  databaseUrl: process.env.DATABASE_URL || '',
  // Use the in-memory PostgreSQL emulator (pg-mem) when no real database is configured
  // for tests, or when explicitly requested for a local demo.
  useMemoryDb:
    process.env.DB_DRIVER === 'memory' ||
    process.argv.includes('--memory') ||
    (isTest && !process.env.DATABASE_URL),
  jwtAccessSecret:
    process.env.JWT_ACCESS_SECRET || (isTest ? 'test-only-access-secret-change-me' : ''),
  accessTokenTtlSeconds: intFromEnv('ACCESS_TOKEN_TTL_SECONDS', 15 * 60),
  refreshTokenTtlSeconds: intFromEnv('REFRESH_TOKEN_TTL_SECONDS', 7 * 24 * 60 * 60),
  bcryptRounds: intFromEnv('BCRYPT_ROUNDS', isTest ? 4 : 12),
  authRateLimitMax: intFromEnv('AUTH_RATE_LIMIT_MAX', isTest ? 1000 : 10),
  authRateLimitWindowMs: intFromEnv('AUTH_RATE_LIMIT_WINDOW_MS', 15 * 60 * 1000),
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  isTest,
};

if (!config.jwtAccessSecret) {
  if (config.useMemoryDb) {
    // Local demo only: a random secret means tokens die with the process.
    config.jwtAccessSecret = require('node:crypto').randomBytes(32).toString('hex');
  } else {
    throw new Error('JWT_ACCESS_SECRET must be set. Copy .env.example to .env.');
  }
}

module.exports = { config };
