import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:task_manager/services/api_client.dart';
import 'package:task_manager/services/token_store.dart';

/// A small in-memory imitation of the Task Manager API for widget tests.
///
/// It is a mock: fast and deterministic, but it cannot prove the real server's
/// authorization or persistence. Those are covered by the backend API tests.
class FakeBackend {
  /// Tasks currently "stored" on the fake server.
  final List<Map<String, dynamic>> tasks = [];

  /// Every request received, as "METHOD /path".
  final List<String> requests = [];

  /// When true, every request fails like a dropped connection.
  bool offline = false;

  /// When set, list requests answer with this status code.
  int? failListWith;

  int _nextId = 1;

  late final MockClient client = MockClient(_handle);

  /// Builds an [ApiClient] that is already signed in against this fake backend.
  ApiClient signedInClient() => ApiClient(
        baseUrl: 'http://api.test',
        httpClient: client,
        tokenStore: InMemoryTokenStore(
          const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
        ),
      );

  /// Builds a signed-out [ApiClient] against this fake backend.
  ApiClient signedOutClient() => ApiClient(
        baseUrl: 'http://api.test',
        httpClient: client,
        tokenStore: InMemoryTokenStore(),
      );

  /// Adds a task directly to the fake store.
  void seed(String title, {bool completed = false}) {
    tasks.add({'id': 'task-${_nextId++}', 'title': title, 'completed': completed});
  }

  /// Number of requests that match [method] and [path].
  int count(String method, String path) =>
      requests.where((r) => r == '$method $path').length;

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    requests.add('${request.method} $path');

    if (offline) {
      throw http.ClientException('Connection failed', request.url);
    }

    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    if (path == '/api/v1/auth/login' || path == '/api/v1/auth/register') {
      if (body['password'] != 'local-test-password') {
        return _json({'error': 'Invalid email or password.'}, 401);
      }
      return _json({
        'user': {'id': 'user-1', 'email': body['email']},
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
      }, path.endsWith('register') ? 201 : 200);
    }
    if (path == '/api/v1/auth/logout') {
      return http.Response('', 204);
    }

    if (path == '/api/v1/tasks' && request.method == 'GET') {
      if (failListWith != null) {
        return _json({'error': 'Could not load tasks.'}, failListWith!);
      }
      return _json({'tasks': tasks.reversed.toList()});
    }

    if (path == '/api/v1/tasks' && request.method == 'POST') {
      final task = {
        'id': 'task-${_nextId++}',
        'title': body['title'],
        'completed': false,
      };
      tasks.add(task);
      return _json(task, 201);
    }

    final match = RegExp(r'^/api/v1/tasks/([^/]+)$').firstMatch(path);
    final index = match == null
        ? -1
        : tasks.indexWhere((t) => t['id'] == match.group(1));
    if (index == -1) {
      return _json({'error': 'Task not found.'}, 404);
    }

    if (request.method == 'PATCH') {
      tasks[index] = {...tasks[index], ...body};
      return _json(tasks[index]);
    }
    if (request.method == 'DELETE') {
      tasks.removeAt(index);
      return http.Response('', 204);
    }
    return _json({'error': 'Not found.'}, 404);
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
