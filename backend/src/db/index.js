'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { config } = require('../config');

const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');

/**
 * Creates the connection pool. Every query in the app goes through parameterized
 * statements on this pool, so user input is never concatenated into SQL.
 *
 * @returns {import('pg').Pool}
 */
function createPool() {
  if (config.useMemoryDb) {
    const { newDb } = require('pg-mem');
    const memoryDb = newDb();
    const { Pool } = memoryDb.adapters.createPg();
    return new Pool();
  }

  const { Pool } = require('pg');
  return new Pool({ connectionString: config.databaseUrl, max: 10 });
}

const pool = createPool();

let migration = null;

/** Applies the schema once per process (the SQL itself is also idempotent). */
function migrate() {
  if (!migration) {
    migration = applySchema().catch((error) => {
      migration = null;
      throw error;
    });
  }
  return migration;
}

async function applySchema() {
  // pg-mem does not accept multiple statements with comments in one call, so run them one by one.
  const statements = schemaSql
    .split(';')
    .map((statement) =>
      statement
        .split('\n')
        .filter((line) => !line.trim().startsWith('--'))
        .join('\n')
        .trim(),
    )
    .filter(Boolean);

  for (const statement of statements) {
    await pool.query(statement);
  }
}

/**
 * Deletes all rows. Only allowed against the in-memory database or when NODE_ENV=test,
 * so a misconfigured run can never wipe a shared or production database.
 */
async function resetForTests() {
  if (!config.isTest && !config.useMemoryDb) {
    throw new Error('resetForTests is only allowed in a test environment.');
  }
  await pool.query('DELETE FROM refresh_tokens');
  await pool.query('DELETE FROM tasks');
  await pool.query('DELETE FROM users');
}

module.exports = { pool, migrate, resetForTests };
