'use strict';

const request = require('supertest');
const { app, createApp } = require('../../src/app');
const { signAccessToken } = require('../../src/auth/tokens');
const { resetDatabase, createTestUser, TEST_PASSWORD, closeDatabase } = require('../helpers');

beforeEach(resetDatabase);
afterAll(closeDatabase);

const auth = (token) => ({ Authorization: `Bearer ${token}` });

describe('register and login', () => {
  test('registers a user and returns a token pair without the password', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'New.User@Example.test', password: TEST_PASSWORD });

    expect(response.status).toBe(201);
    expect(response.body.user.email).toBe('new.user@example.test');
    expect(response.body.accessToken).toEqual(expect.any(String));
    expect(response.body.refreshToken).toEqual(expect.any(String));
    expect(JSON.stringify(response.body)).not.toContain(TEST_PASSWORD);
    expect(JSON.stringify(response.body)).not.toMatch(/password_hash|passwordHash/);
  });

  test('rejects a duplicate email', async () => {
    const user = await createTestUser();
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: user.email, password: TEST_PASSWORD });
    expect(response.status).toBe(409);
  });

  test.each([
    ['too short (7)', 'p'.repeat(7), 400],
    ['minimum (8)', 'p'.repeat(8), 201],
    ['maximum (72)', 'p'.repeat(72), 201],
    ['too long (73)', 'p'.repeat(73), 400],
    ['empty', '', 400],
    ['wrong type', 12345678, 400],
  ])('register password boundary: %s', async (_label, password, expected) => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: `boundary${Math.random()}@example.test`, password });
    expect(response.status).toBe(expected);
  });

  test('logs in with valid credentials', async () => {
    const user = await createTestUser();
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: TEST_PASSWORD });
    expect(response.status).toBe(200);
    expect(response.body.accessToken).toEqual(expect.any(String));
  });

  test('wrong password and unknown email give the same response', async () => {
    const user = await createTestUser();
    const wrongPassword = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: 'wrong-password' });
    const unknownEmail = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'nobody@example.test', password: 'wrong-password' });

    expect(wrongPassword.status).toBe(401);
    expect(unknownEmail.status).toBe(401);
    expect(wrongPassword.body).toEqual(unknownEmail.body);
  });
});

describe('access tokens', () => {
  test('a missing token is rejected', async () => {
    const response = await request(app).get('/api/v1/tasks');
    expect(response.status).toBe(401);
  });

  test('a garbage token is rejected', async () => {
    const response = await request(app).get('/api/v1/tasks').set(auth('not.a.jwt'));
    expect(response.status).toBe(401);
  });

  test('a non-Bearer scheme is rejected', async () => {
    const user = await createTestUser();
    const response = await request(app)
      .get('/api/v1/tasks')
      .set('Authorization', `Basic ${user.accessToken}`);
    expect(response.status).toBe(401);
  });

  test('an expired access token is rejected', async () => {
    const user = await createTestUser();
    const expired = signAccessToken(user.userId, { expiresInSeconds: -1 });
    const response = await request(app).get('/api/v1/tasks').set(auth(expired));
    expect(response.status).toBe(401);
    expect(response.body).toEqual({ error: 'Invalid or expired token.' });
  });

  test('a refresh token cannot be used as an access token', async () => {
    const user = await createTestUser();
    const response = await request(app).get('/api/v1/tasks').set(auth(user.refreshToken));
    expect(response.status).toBe(401);
  });
});

describe('refresh token rotation', () => {
  test('refresh returns a new pair and the new access token works', async () => {
    const user = await createTestUser();

    const refreshed = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken });

    expect(refreshed.status).toBe(200);
    expect(refreshed.body.refreshToken).not.toBe(user.refreshToken);

    const list = await request(app).get('/api/v1/tasks').set(auth(refreshed.body.accessToken));
    expect(list.status).toBe(200);
  });

  test('reusing an old refresh token is detected and revokes the whole family', async () => {
    const user = await createTestUser();
    const first = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken });
    expect(first.status).toBe(200);

    // An attacker replays the original (already rotated) token.
    const replay = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken });
    expect(replay.status).toBe(401);
    expect(replay.body.error).toMatch(/reuse detected/i);

    // The legitimate newest token is now revoked too.
    const legit = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: first.body.refreshToken });
    expect(legit.status).toBe(401);
  });

  test.each([
    ['missing', undefined],
    ['empty', ''],
    ['unknown', 'definitely-not-a-real-token'],
    ['wrong type', 123],
    ['oversized', 'x'.repeat(5000)],
  ])('an invalid refresh token (%s) is rejected', async (_label, refreshToken) => {
    const response = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });
    expect(response.status).toBe(401);
  });
});

describe('logout', () => {
  test('logout revokes the refresh token', async () => {
    const user = await createTestUser();

    const logout = await request(app)
      .post('/api/v1/auth/logout')
      .send({ refreshToken: user.refreshToken });
    expect(logout.status).toBe(204);

    const refresh = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: user.refreshToken });
    expect(refresh.status).toBe(401);
  });

  test('logout is idempotent for unknown tokens', async () => {
    const response = await request(app)
      .post('/api/v1/auth/logout')
      .send({ refreshToken: 'unknown-token' });
    expect(response.status).toBe(204);
  });

  test('logout on one device does not end the other session', async () => {
    const user = await createTestUser();
    const secondDevice = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: TEST_PASSWORD });

    await request(app).post('/api/v1/auth/logout').send({ refreshToken: user.refreshToken });

    const refresh = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: secondDevice.body.refreshToken });
    expect(refresh.status).toBe(200);
  });

  test('logout-all revokes every session of the user', async () => {
    const user = await createTestUser();
    const secondDevice = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: user.email, password: TEST_PASSWORD });

    const logoutAll = await request(app)
      .post('/api/v1/auth/logout-all')
      .set(auth(user.accessToken));
    expect(logoutAll.status).toBe(204);

    for (const refreshToken of [user.refreshToken, secondDevice.body.refreshToken]) {
      const response = await request(app).post('/api/v1/auth/refresh').send({ refreshToken });
      expect(response.status).toBe(401);
    }
  });

  test('logout-all requires authentication', async () => {
    const response = await request(app).post('/api/v1/auth/logout-all');
    expect(response.status).toBe(401);
  });

  test("logout-all of one user does not affect another user's sessions", async () => {
    const alice = await createTestUser();
    const bob = await createTestUser();

    await request(app).post('/api/v1/auth/logout-all').set(auth(alice.accessToken));

    const bobRefresh = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: bob.refreshToken });
    expect(bobRefresh.status).toBe(200);
  });
});

describe('rate limiting (small, authorized local run)', () => {
  test('login attempts beyond the limit get a safe 429', async () => {
    const limitedApp = createApp({ authRateLimitMax: 3, authRateLimitWindowMs: 60_000 });
    const attempt = () =>
      request(limitedApp)
        .post('/api/v1/auth/login')
        .send({ email: 'nobody@example.test', password: 'wrong-password' });

    const statuses = [];
    for (let i = 0; i < 4; i += 1) {
      statuses.push((await attempt()).status);
    }

    expect(statuses).toEqual([401, 401, 401, 429]);
    const blocked = await attempt();
    expect(blocked.body).toEqual({ error: 'Too many attempts. Try again later.' });
    expect(blocked.headers).toHaveProperty('ratelimit-policy');
  });
});
