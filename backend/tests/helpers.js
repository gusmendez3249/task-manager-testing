'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { migrate, resetForTests, pool } = require('../src/db');

let counter = 0;

// Synthetic test password, never a real one. Meets the 8-72 character rule.
const TEST_PASSWORD = 'local-test-password';

/** Applies the schema and empties the isolated test database. Call in beforeEach. */
async function resetDatabase() {
  await migrate();
  await resetForTests();
}

/**
 * Registers a unique synthetic user.
 *
 * @param {import('express').Express} [targetApp]
 * @returns {Promise<{ email: string, accessToken: string, refreshToken: string, userId: string }>}
 */
async function createTestUser(targetApp = app) {
  counter += 1;
  const email = `tester${Date.now()}-${counter}@example.test`;
  const response = await request(targetApp)
    .post('/api/v1/auth/register')
    .send({ email, password: TEST_PASSWORD });

  if (response.status !== 201) {
    throw new Error(`Could not create test user: ${response.status}`);
  }
  return {
    email,
    accessToken: response.body.accessToken,
    refreshToken: response.body.refreshToken,
    userId: response.body.user.id,
  };
}

/** Shortcut matching the tutorial: returns only the access token. */
async function createTestUserAndGetToken() {
  const user = await createTestUser();
  return user.accessToken;
}

/**
 * @param {string} token
 * @param {string} title
 * @returns {Promise<string>} The created task id.
 */
async function createTask(token, title) {
  const response = await request(app)
    .post('/api/v1/tasks')
    .set('Authorization', `Bearer ${token}`)
    .send({ title });

  if (response.status !== 201) {
    throw new Error(`Could not create task: ${response.status}`);
  }
  return response.body.id;
}

async function closeDatabase() {
  await pool.end();
}

module.exports = {
  TEST_PASSWORD,
  resetDatabase,
  createTestUser,
  createTestUserAndGetToken,
  createTask,
  closeDatabase,
};
