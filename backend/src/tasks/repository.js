'use strict';

const crypto = require('node:crypto');
const { pool } = require('../db');

/**
 * Every query here is scoped by owner_id. That is the object-level authorization check:
 * a task that belongs to someone else simply is not found.
 */

/** @param {Record<string, any>} row */
function toTask(row) {
  return {
    id: row.id,
    title: row.title,
    completed: row.completed,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

/**
 * @param {string} ownerId
 * @param {{ limit: number, offset: number }} page
 */
async function listTasks(ownerId, { limit, offset }) {
  const result = await pool.query(
    `SELECT id, title, completed, created_at, updated_at FROM tasks
     WHERE owner_id = $1 ORDER BY created_at DESC, id ASC LIMIT $2 OFFSET $3`,
    [ownerId, limit, offset],
  );
  return result.rows.map(toTask);
}

/**
 * @param {string} ownerId
 * @param {string} id
 */
async function findTask(ownerId, id) {
  const result = await pool.query(
    'SELECT id, title, completed, created_at, updated_at FROM tasks WHERE id = $1 AND owner_id = $2',
    [id, ownerId],
  );
  return result.rows[0] ? toTask(result.rows[0]) : null;
}

/**
 * @param {string} ownerId
 * @param {string} title
 */
async function createTask(ownerId, title) {
  const id = crypto.randomUUID();
  const result = await pool.query(
    `INSERT INTO tasks (id, owner_id, title) VALUES ($1, $2, $3)
     RETURNING id, title, completed, created_at, updated_at`,
    [id, ownerId, title],
  );
  return toTask(result.rows[0]);
}

/**
 * Updates only the whitelisted fields that were provided.
 *
 * @param {string} ownerId
 * @param {string} id
 * @param {{ title?: string, completed?: boolean }} changes
 */
async function updateTask(ownerId, id, changes) {
  const current = await findTask(ownerId, id);
  if (!current) {
    return null;
  }
  const title = changes.title ?? current.title;
  const completed = changes.completed ?? current.completed;

  const result = await pool.query(
    `UPDATE tasks SET title = $1, completed = $2, updated_at = NOW()
     WHERE id = $3 AND owner_id = $4
     RETURNING id, title, completed, created_at, updated_at`,
    [title, completed, id, ownerId],
  );
  return result.rows[0] ? toTask(result.rows[0]) : null;
}

/**
 * @param {string} ownerId
 * @param {string} id
 * @returns {Promise<boolean>} Whether a task was deleted.
 */
async function deleteTask(ownerId, id) {
  const result = await pool.query('DELETE FROM tasks WHERE id = $1 AND owner_id = $2', [
    id,
    ownerId,
  ]);
  return result.rowCount > 0;
}

module.exports = { listTasks, findTask, createTask, updateTask, deleteTask };
