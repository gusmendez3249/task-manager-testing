import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:task_manager/services/api_client.dart';
import 'package:task_manager/services/token_store.dart';

// Section 15: mocked API-client tests. They are fast and deterministic, and they
// check client behavior (headers, refresh, error mapping). They CANNOT prove the
// server enforces ownership; backend/tests/api covers that against a database.

const _oldTokens = AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh');

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _task(String id, String title) =>
    {'id': id, 'title': title, 'completed': false};

ApiClient _client(MockClient mock, [AuthTokens? tokens = _oldTokens]) => ApiClient(
      baseUrl: 'http://api.test/',
      httpClient: mock,
      tokenStore: InMemoryTokenStore(tokens),
    );

void main() {
  test('login stores the token pair', () async {
    final store = InMemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'http://api.test/api/v1/auth/login');
        expect(jsonDecode(request.body),
            {'email': 'tester@example.test', 'password': 'local-test-password'});
        return _json({'accessToken': 'a1', 'refreshToken': 'r1'});
      }),
    );

    await api.login(' tester@example.test ', 'local-test-password');

    final tokens = await store.read();
    expect(tokens?.accessToken, 'a1');
    expect(tokens?.refreshToken, 'r1');
  });

  test('login shows the server message on 401', () async {
    final api = _client(
      MockClient((_) async => _json({'error': 'Invalid email or password.'}, 401)),
      null,
    );
    await expectLater(
      api.login('tester@example.test', 'wrong-password'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Invalid email or password.')),
    );
  });

  test('sends the bearer token', () async {
    final api = _client(MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer old-access');
      return _json({'tasks': [_task('t1', 'Plan tests')]});
    }));

    final tasks = await api.listTasks();
    expect(tasks.single.title, 'Plan tests');
  });

  test('refreshes once on 401 and retries with the new access token', () async {
    final calls = <String>[];
    final store = InMemoryTokenStore(_oldTokens);
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokenStore: store,
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/v1/auth/refresh') {
          expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});
          return _json({'accessToken': 'new-access', 'refreshToken': 'new-refresh'});
        }
        if (request.headers['Authorization'] == 'Bearer old-access') {
          return _json({'error': 'Invalid or expired token.'}, 401);
        }
        return _json({'tasks': []});
      }),
    );

    expect(await api.listTasks(), isEmpty);
    expect(calls, [
      'GET /api/v1/tasks',
      'POST /api/v1/auth/refresh',
      'GET /api/v1/tasks',
    ]);
    expect((await store.read())?.refreshToken, 'new-refresh');
  });

  test('parallel 401s share a single refresh', () async {
    var refreshes = 0;
    final api = _client(MockClient((request) async {
      if (request.url.path == '/api/v1/auth/refresh') {
        refreshes++;
        return _json({'accessToken': 'new-access', 'refreshToken': 'new-refresh'});
      }
      if (request.headers['Authorization'] == 'Bearer old-access') {
        return _json({'error': 'Invalid or expired token.'}, 401);
      }
      return _json({'tasks': []});
    }));

    await Future.wait([api.listTasks(), api.listTasks(), api.listTasks()]);
    expect(refreshes, 1);
  });

  test('a failed refresh clears the session and reports unauthorized', () async {
    final store = InMemoryTokenStore(_oldTokens);
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokenStore: store,
      httpClient: MockClient((request) async =>
          _json({'error': 'Refresh token reuse detected.'}, 401)),
    );

    await expectLater(api.listTasks(), throwsA(isA<UnauthorizedException>()));
    expect(await store.read(), isNull);
  });

  test('no stored session is unauthorized without calling the network', () async {
    var calls = 0;
    final api = _client(MockClient((_) async {
      calls++;
      return _json({});
    }), null);

    await expectLater(api.listTasks(), throwsA(isA<UnauthorizedException>()));
    expect(calls, 0);
  });

  test('a dropped connection becomes a friendly offline error', () async {
    final api = _client(MockClient((request) async {
      throw http.ClientException('Connection refused', request.url);
    }));

    await expectLater(
      api.createTask('Plan tests'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', ApiClient.offlineMessage)),
    );
  });

  test('a malformed task list is rejected safely', () async {
    final api = _client(MockClient((_) async => _json({
          'tasks': [
            {'id': 7, 'title': null},
          ],
        })));

    await expectLater(
      api.listTasks(),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', ApiClient.unexpectedMessage)),
    );
  });

  test('non-JSON responses are rejected safely', () async {
    final api = _client(MockClient((_) async => http.Response('<html>', 200)));
    await expectLater(api.listTasks(), throwsA(isA<ApiException>()));
  });

  test('500 errors do not leak server details', () async {
    final api = _client(MockClient(
        (_) async => _json({'error': 'SELECT * FROM tasks failed at line 3'}, 500)));
    await expectLater(
      api.listTasks(),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', 'The server had a problem. Try again later.')),
    );
  });

  test('429 is explained to the user', () async {
    final api = _client(MockClient((_) async => _json({'error': 'x'}, 429)), null);
    await expectLater(
      api.login('tester@example.test', 'local-test-password'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
    );
  });

  test('task ids are URL-encoded', () async {
    final api = _client(MockClient((request) async {
      expect(request.url.path, '/api/v1/tasks/a%2Fb');
      return http.Response('', 204);
    }));
    await api.deleteTask('a/b');
  });

  test('update sends only the provided fields', () async {
    final api = _client(MockClient((request) async {
      expect(jsonDecode(request.body), {'completed': true});
      return _json({'id': 't1', 'title': 'x', 'completed': true});
    }));
    final task = await api.updateTask('t1', completed: true);
    expect(task.completed, isTrue);
  });

  test('logout clears local tokens even when offline', () async {
    final store = InMemoryTokenStore(_oldTokens);
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokenStore: store,
      httpClient: MockClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
    );

    await api.logout();
    expect(await store.read(), isNull);
  });
}
