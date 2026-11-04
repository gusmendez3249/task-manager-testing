'use strict';

const express = require('express');
const { HttpError, badRequestOnTypeError } = require('../errors');
const { authenticate } = require('../middleware/authenticate');
const repository = require('./repository');
const { validateTitle, validateCompleted, isUuid, parsePagination } = require('./validation');

// Same response for "does not exist", "belongs to someone else", and "malformed id",
// so the API never discloses whether another user's task exists.
const NOT_FOUND = 'Task not found.';

/** @param {string} id */
function requireTaskId(id) {
  if (!isUuid(id)) {
    throw new HttpError(404, NOT_FOUND);
  }
  return id;
}

function createTaskRouter() {
  const router = express.Router();
  router.use(authenticate);

  router.get('/', async (req, res) => {
    const page = badRequestOnTypeError(() => parsePagination(req.query));
    const tasks = await repository.listTasks(req.userId, page);
    res.json({ tasks, limit: page.limit, offset: page.offset });
  });

  router.post('/', async (req, res) => {
    // Only "title" is read. Fields such as ownerId or id in the body are ignored:
    // ownership always comes from the verified token.
    const title = badRequestOnTypeError(() => validateTitle(req.body?.title));
    const task = await repository.createTask(req.userId, title);
    res.status(201).json(task);
  });

  router.get('/:id', async (req, res) => {
    const task = await repository.findTask(req.userId, requireTaskId(req.params.id));
    if (!task) {
      throw new HttpError(404, NOT_FOUND);
    }
    res.json(task);
  });

  router.patch('/:id', async (req, res) => {
    const id = requireTaskId(req.params.id);
    const body = req.body ?? {};
    const changes = {};

    if (body.title !== undefined) {
      changes.title = badRequestOnTypeError(() => validateTitle(body.title));
    }
    if (body.completed !== undefined) {
      changes.completed = badRequestOnTypeError(() => validateCompleted(body.completed));
    }
    if (Object.keys(changes).length === 0) {
      throw new HttpError(400, 'Provide a title or completed value to update.');
    }

    const task = await repository.updateTask(req.userId, id, changes);
    if (!task) {
      throw new HttpError(404, NOT_FOUND);
    }
    res.json(task);
  });

  router.delete('/:id', async (req, res) => {
    const deleted = await repository.deleteTask(req.userId, requireTaskId(req.params.id));
    if (!deleted) {
      throw new HttpError(404, NOT_FOUND);
    }
    res.status(204).end();
  });

  return router;
}

module.exports = { createTaskRouter };
