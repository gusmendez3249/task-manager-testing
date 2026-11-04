// Authenticated read workload for a LOCAL or dedicated test environment only.
// Creates one synthetic user in setup(); stop condition: thresholds abort the run on failure.
//   BASE_URL=http://localhost:3000 k6 run perf/tasks-list-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export const options = {
  stages: [
    { duration: '10s', target: 5 },
    { duration: '20s', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_failed: [{ threshold: 'rate<0.01', abortOnFail: true }],
    http_req_duration: ['p(95)<500'],
    checks: ['rate>0.99'],
  },
};

export function setup() {
  const email = `k6-${Date.now()}@example.test`;
  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post(
    `${BASE_URL}/api/v1/auth/register`,
    JSON.stringify({ email, password: 'local-test-password' }),
    params,
  );
  const token = res.json('accessToken');
  for (let i = 0; i < 20; i += 1) {
    http.post(`${BASE_URL}/api/v1/tasks`, JSON.stringify({ title: `Load task ${i}` }), {
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    });
  }
  return { token };
}

export default function (data) {
  const res = http.get(`${BASE_URL}/api/v1/tasks?limit=20`, {
    headers: { Authorization: `Bearer ${data.token}` },
  });
  check(res, {
    'list returns 200': (r) => r.status === 200,
    'list has 20 tasks': (r) => r.json('tasks').length === 20,
  });
  sleep(1);
}
