'use strict';

const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { config } = require('../config');
const { HttpError } = require('../errors');
const { signAccessToken, generateRefreshToken, hashRefreshToken } = require('./tokens');

// Compared against when the email is unknown, so login takes similar time either way.
const DUMMY_HASH = bcrypt.hashSync('not-a-real-password', 4);

/**
 * Stores a new refresh token in a family and returns the token pair.
 *
 * @param {string} userId
 * @param {string} familyId - Rotation family; reuse of an old member revokes the family.
 */
async function issueTokenPair(userId, familyId) {
  const refreshToken = generateRefreshToken();
  const expiresAt = new Date(Date.now() + config.refreshTokenTtlSeconds * 1000);

  await pool.query(
    `INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [crypto.randomUUID(), userId, familyId, hashRefreshToken(refreshToken), expiresAt],
  );

  return {
    accessToken: signAccessToken(userId),
    refreshToken,
    tokenType: 'Bearer',
    expiresIn: config.accessTokenTtlSeconds,
  };
}

/**
 * @param {string} email - Already validated.
 * @param {string} password - Already validated.
 */
async function register(email, password) {
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    throw new HttpError(409, 'An account with this email already exists.');
  }

  const id = crypto.randomUUID();
  const passwordHash = await bcrypt.hash(password, config.bcryptRounds);
  await pool.query('INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)', [
    id,
    email,
    passwordHash,
  ]);

  const tokens = await issueTokenPair(id, crypto.randomUUID());
  return { user: { id, email }, ...tokens };
}

/**
 * @param {string} email
 * @param {string} password
 */
async function login(email, password) {
  const result = await pool.query('SELECT id, email, password_hash FROM users WHERE email = $1', [
    email,
  ]);
  const user = result.rows[0];
  const passwordOk = await bcrypt.compare(password, user ? user.password_hash : DUMMY_HASH);

  if (!user || !passwordOk) {
    // Same message for unknown email and wrong password: do not reveal which accounts exist.
    throw new HttpError(401, 'Invalid email or password.');
  }

  const tokens = await issueTokenPair(user.id, crypto.randomUUID());
  return { user: { id: user.id, email: user.email }, ...tokens };
}

/**
 * Rotates a refresh token. Presenting an already-used (revoked) token is treated as theft:
 * the whole token family is revoked so the attacker and the victim must sign in again.
 *
 * @param {unknown} refreshToken
 */
async function refresh(refreshToken) {
  if (typeof refreshToken !== 'string' || refreshToken.length === 0 || refreshToken.length > 200) {
    throw new HttpError(401, 'Invalid refresh token.');
  }

  const result = await pool.query(
    'SELECT id, user_id, family_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = $1',
    [hashRefreshToken(refreshToken)],
  );
  const stored = result.rows[0];

  if (!stored) {
    throw new HttpError(401, 'Invalid refresh token.');
  }

  if (stored.revoked_at) {
    await pool.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = $1 AND revoked_at IS NULL',
      [stored.family_id],
    );
    throw new HttpError(401, 'Refresh token reuse detected. Please sign in again.');
  }

  if (new Date(stored.expires_at).getTime() <= Date.now()) {
    throw new HttpError(401, 'Refresh token expired. Please sign in again.');
  }

  await pool.query('UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1', [stored.id]);
  return issueTokenPair(stored.user_id, stored.family_id);
}

/**
 * Revokes one session (the refresh token's family). Unknown tokens are ignored so logout
 * is idempotent and does not reveal whether a token was valid.
 *
 * @param {unknown} refreshToken
 */
async function logout(refreshToken) {
  if (typeof refreshToken !== 'string' || refreshToken.length === 0 || refreshToken.length > 200) {
    return;
  }
  const result = await pool.query('SELECT family_id FROM refresh_tokens WHERE token_hash = $1', [
    hashRefreshToken(refreshToken),
  ]);
  if (result.rows[0]) {
    await pool.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = $1 AND revoked_at IS NULL',
      [result.rows[0].family_id],
    );
  }
}

/**
 * Revokes every session of a user.
 *
 * @param {string} userId - From the verified access token.
 */
async function logoutAll(userId) {
  await pool.query(
    'UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL',
    [userId],
  );
}

module.exports = { register, login, refresh, logout, logoutAll };
