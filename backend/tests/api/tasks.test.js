'use strict';

const request = require('supertest');
const { app } = require('../../src/app');
const {
  resetDatabase,
  createTestUser,
  createTestUserAndGetToken,
  createTask,
  closeDatabase,
} = require('../helpers');

beforeEach(resetDatabase);
afterAll(closeDatabase);

const auth = (token) => ({ Authorization: `Bearer ${token}` });

describe('task API security', () => {
  test('rejects task creation without authentication', async () => {
    const response = await request(app).post('/api/v1/tasks').send({ title: 'Plan tests' });

    expect(response.status).toBe(401);
  });

  test('rejects an empty title', async () => {
    const token = await createTestUserAndGetToken();

    const response = await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${token}`)
      .send({ title: '   ' });

    expect(response.status).toBe(400);
  });

  test('does not let one user read another user task', async () => {
    const owner = await createTestUserAndGetToken();
    const stranger = await createTestUserAndGetToken();
    const taskId = await createTask(owner, 'Private task');

    const response = await request(app)
      .get(`/api/v1/tasks/${taskId}`)
      .set('Authorization', `Bearer ${stranger}`);

    expect([403, 404]).toContain(response.status);
  });
});

describe('task CRUD (happy path)', () => {
  test('a signed-in user can create a task and see it in the list', async () => {
    const token = await createTestUserAndGetToken();

    const created = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: '  Plan tests  ' });

    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ title: 'Plan tests', completed: false });
    expect(created.body).not.toHaveProperty('ownerId');

    const list = await request(app).get('/api/v1/tasks').set(auth(token));
    expect(list.status).toBe(200);
    expect(list.body.tasks.map((t) => t.title)).toEqual(['Plan tests']);
  });

  test('a new user starts with an empty list', async () => {
    const token = await createTestUserAndGetToken();
    const list = await request(app).get('/api/v1/tasks').set(auth(token));
    expect(list.body.tasks).toEqual([]);
  });

  test('a task can be renamed, read, and deleted', async () => {
    const token = await createTestUserAndGetToken();
    const id = await createTask(token, 'Draft');

    const renamed = await request(app)
      .patch(`/api/v1/tasks/${id}`)
      .set(auth(token))
      .send({ title: 'Final' });
    expect(renamed.status).toBe(200);
    expect(renamed.body.title).toBe('Final');

    const read = await request(app).get(`/api/v1/tasks/${id}`).set(auth(token));
    expect(read.body.title).toBe('Final');

    const deleted = await request(app).delete(`/api/v1/tasks/${id}`).set(auth(token));
    expect(deleted.status).toBe(204);

    const gone = await request(app).get(`/api/v1/tasks/${id}`).set(auth(token));
    expect(gone.status).toBe(404);
  });

  // Regression test for BUG-001 in docs/03-reporte-de-bug.md:
  // "A task disappears after being marked complete."
  test('a completed task stays in the list and is marked completed', async () => {
    const token = await createTestUserAndGetToken();
    const id = await createTask(token, 'Finish report');

    const completed = await request(app)
      .patch(`/api/v1/tasks/${id}`)
      .set(auth(token))
      .send({ completed: true });
    expect(completed.status).toBe(200);
    expect(completed.body.completed).toBe(true);

    const list = await request(app).get('/api/v1/tasks').set(auth(token));
    expect(list.body.tasks).toEqual([
      expect.objectContaining({ id, title: 'Finish report', completed: true }),
    ]);
  });

  test('pagination is bounded', async () => {
    const token = await createTestUserAndGetToken();
    for (const title of ['one', 'two', 'three']) {
      await createTask(token, title);
    }

    const page = await request(app).get('/api/v1/tasks?limit=2').set(auth(token));
    expect(page.body.tasks).toHaveLength(2);

    const tooBig = await request(app).get('/api/v1/tasks?limit=1000').set(auth(token));
    expect(tooBig.status).toBe(400);
  });
});

// Practice exercise (section 6): invalid task ID, missing title, updating another user's task.
describe('negative API behavior', () => {
  test('an invalid task ID returns 404 without leaking details', async () => {
    const token = await createTestUserAndGetToken();

    const response = await request(app).get('/api/v1/tasks/not-a-valid-id').set(auth(token));

    expect(response.status).toBe(404);
    expect(response.body).toEqual({ error: 'Task not found.' });
  });

  test('a well-formed but unknown task ID returns the same 404', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .get('/api/v1/tasks/3f2b8c1e-9d4a-4b7e-8f21-0a1b2c3d4e5f')
      .set(auth(token));
    expect(response.status).toBe(404);
    expect(response.body).toEqual({ error: 'Task not found.' });
  });

  test('a missing title is rejected', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app).post('/api/v1/tasks').set(auth(token)).send({});
    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Enter a valid title.');
  });

  test.each([
    ['number', 42],
    ['null', null],
    ['array', ['x']],
    ['121 characters', 'a'.repeat(121)],
  ])('a title of the wrong shape (%s) is rejected safely', async (_label, title) => {
    const token = await createTestUserAndGetToken();
    const response = await request(app).post('/api/v1/tasks').set(auth(token)).send({ title });
    expect(response.status).toBe(400);
    expect(JSON.stringify(response.body)).not.toMatch(/stack|sql|select/i);
  });

  test('a title of exactly 120 characters is accepted', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: 'a'.repeat(120) });
    expect(response.status).toBe(201);
  });

  test('a user cannot update another user task', async () => {
    const owner = await createTestUserAndGetToken();
    const stranger = await createTestUserAndGetToken();
    const taskId = await createTask(owner, 'Private task');

    const response = await request(app)
      .patch(`/api/v1/tasks/${taskId}`)
      .set(auth(stranger))
      .send({ title: 'Hijacked' });
    expect(response.status).toBe(404);

    const ownerView = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(owner));
    expect(ownerView.body.title).toBe('Private task');
  });

  test('a user cannot delete another user task', async () => {
    const owner = await createTestUserAndGetToken();
    const stranger = await createTestUserAndGetToken();
    const taskId = await createTask(owner, 'Private task');

    const response = await request(app).delete(`/api/v1/tasks/${taskId}`).set(auth(stranger));
    expect(response.status).toBe(404);

    const ownerView = await request(app).get(`/api/v1/tasks/${taskId}`).set(auth(owner));
    expect(ownerView.status).toBe(200);
  });

  test("another user's list never includes my tasks", async () => {
    const owner = await createTestUserAndGetToken();
    const stranger = await createTestUserAndGetToken();
    await createTask(owner, 'Private task');

    const list = await request(app).get('/api/v1/tasks').set(auth(stranger));
    expect(list.body.tasks).toEqual([]);
  });

  test('an update with no supported fields is rejected', async () => {
    const token = await createTestUserAndGetToken();
    const id = await createTask(token, 'Task');
    const response = await request(app)
      .patch(`/api/v1/tasks/${id}`)
      .set(auth(token))
      .send({ color: 'red' });
    expect(response.status).toBe(400);
  });

  test('completed must be a boolean', async () => {
    const token = await createTestUserAndGetToken();
    const id = await createTask(token, 'Task');
    const response = await request(app)
      .patch(`/api/v1/tasks/${id}`)
      .set(auth(token))
      .send({ completed: 'yes' });
    expect(response.status).toBe(400);
  });

  test('malformed JSON returns a safe 400', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .set('Content-Type', 'application/json')
      .send('{"title": ');
    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Request body must be valid JSON.' });
  });

  test('an oversized body is rejected with 413', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .post('/api/v1/tasks')
      .set(auth(token))
      .send({ title: 'x', padding: 'y'.repeat(20 * 1024) });
    expect(response.status).toBe(413);
  });
});

// Section 9: injection-looking input and mass assignment (OWASP API3).
describe('security basics', () => {
  test('an SQL-injection-looking title is stored as plain text', async () => {
    const token = await createTestUserAndGetToken();
    const other = await createTestUserAndGetToken();
    await createTask(other, 'Someone else');
    const title = "' OR '1'='1";

    const created = await request(app).post('/api/v1/tasks').set(auth(token)).send({ title });
    expect(created.status).toBe(201);
    expect(created.body.title).toBe(title);

    const list = await request(app).get('/api/v1/tasks').set(auth(token));
    expect(list.body.tasks.map((t) => t.title)).toEqual([title]);
  });

  test('an injection-looking task id does not reach the database as SQL', async () => {
    const token = await createTestUserAndGetToken();
    const response = await request(app)
      .get(`/api/v1/tasks/${encodeURIComponent("1' OR '1'='1")}`)
      .set(auth(token));
    expect(response.status).toBe(404);
  });

  test('markup-like input is returned as data, not interpreted', async () => {
    const token = await createTestUserAndGetToken();
    const title = '<script>alert(1)</script>';
    const created = await request(app).post('/api/v1/tasks').set(auth(token)).send({ title });
    expect(created.headers['content-type']).toMatch(/application\/json/);
    expect(created.body.title).toBe(title);
  });

  test('ownerId in the body is ignored when creating a task', async () => {
    const owner = await createTestUser();
    const attacker = await createTestUser();

    const created = await request(app)
      .post('/api/v1/tasks')
      .set(auth(attacker.accessToken))
      .send({ title: 'Planted', ownerId: owner.userId, owner_id: owner.userId });
    expect(created.status).toBe(201);

    const ownerList = await request(app).get('/api/v1/tasks').set(auth(owner.accessToken));
    expect(ownerList.body.tasks).toEqual([]);

    const attackerList = await request(app).get('/api/v1/tasks').set(auth(attacker.accessToken));
    expect(attackerList.body.tasks.map((t) => t.title)).toEqual(['Planted']);
  });

  // Practice exercise (section 9): update a task with an ownerId field.
  test('ownerId in an update is ignored and ownership is retained', async () => {
    const owner = await createTestUser();
    const other = await createTestUser();
    const id = await createTask(owner.accessToken, 'Mine');

    const updated = await request(app)
      .patch(`/api/v1/tasks/${id}`)
      .set(auth(owner.accessToken))
      .send({ title: 'Still mine', ownerId: other.userId });
    expect(updated.status).toBe(200);

    const ownerView = await request(app).get(`/api/v1/tasks/${id}`).set(auth(owner.accessToken));
    expect(ownerView.status).toBe(200);
    expect(ownerView.body.title).toBe('Still mine');

    const otherView = await request(app).get(`/api/v1/tasks/${id}`).set(auth(other.accessToken));
    expect(otherView.status).toBe(404);
  });

  test('responses include safe headers and no x-powered-by', async () => {
    const response = await request(app).get('/health');
    expect(response.headers['x-powered-by']).toBeUndefined();
    expect(response.headers['x-content-type-options']).toBe('nosniff');
  });

  test('unknown routes return a JSON 404', async () => {
    const response = await request(app).get('/api/v0/tasks');
    expect(response.status).toBe(404);
    expect(response.body).toEqual({ error: 'Not found.' });
  });
});

describe('health', () => {
  test('returns 200', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
});
