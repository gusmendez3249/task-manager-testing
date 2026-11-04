'use strict';

const jwt = require('jsonwebtoken');
const {
  signAccessToken,
  verifyAccessToken,
  generateRefreshToken,
  hashRefreshToken,
} = require('../../src/auth/tokens');

describe('access tokens', () => {
  test('round-trips the user id', () => {
    const token = signAccessToken('user-1');
    expect(verifyAccessToken(token)).toBe('user-1');
  });

  test('rejects an expired token', () => {
    const token = signAccessToken('user-1', { expiresInSeconds: -10 });
    expect(() => verifyAccessToken(token)).toThrow();
  });

  test('rejects a token signed with another secret', () => {
    const forged = jwt.sign({ sub: 'user-1', type: 'access' }, 'attacker-secret', {
      issuer: 'task-manager-api',
    });
    expect(() => verifyAccessToken(forged)).toThrow();
  });

  test('rejects the "none" algorithm', () => {
    const unsigned = jwt.sign({ sub: 'user-1', type: 'access' }, '', {
      algorithm: 'none',
      issuer: 'task-manager-api',
    });
    expect(() => verifyAccessToken(unsigned)).toThrow();
  });
});

describe('refresh tokens', () => {
  test('are random and long', () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toBe(b);
    expect(a.length).toBeGreaterThanOrEqual(40);
  });

  test('hash is deterministic and does not contain the token', () => {
    const token = generateRefreshToken();
    expect(hashRefreshToken(token)).toBe(hashRefreshToken(token));
    expect(hashRefreshToken(token)).not.toContain(token);
  });
});
