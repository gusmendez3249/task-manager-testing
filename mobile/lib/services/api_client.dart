import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'token_store.dart';

/// An error whose [message] is safe to show to the user.
class ApiException implements Exception {
  /// Creates an API error.
  const ApiException(this.message, {this.statusCode});

  /// User-facing message. Never contains tokens or stack traces.
  final String message;

  /// HTTP status, when the server answered.
  final int? statusCode;

  @override
  String toString() => message;
}

/// The session is missing, expired, or was revoked. The user must sign in again.
class UnauthorizedException extends ApiException {
  /// Creates an unauthorized error.
  const UnauthorizedException(
      [super.message = 'Your session has ended. Please sign in again.'])
      : super(statusCode: 401);
}

/// Talks to the Task Manager REST API and keeps the token pair fresh.
class ApiClient {
  /// Creates a client. Inject [httpClient] in tests to avoid the real network.
  ApiClient({
    required String baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();

  static const offlineMessage =
      'Could not reach the server. Check your connection and try again.';
  static const unexpectedMessage = 'Unexpected response from the server.';
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  final String _baseUrl;
  final http.Client _http;

  /// Where the session tokens are kept.
  final TokenStore tokenStore;

  /// Maximum time to wait for one request.
  final Duration timeout;

  Future<AuthTokens>? _refreshing;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Whether tokens are stored from a previous session.
  Future<bool> hasSession() async => (await tokenStore.read()) != null;

  /// Signs in and stores the token pair.
  Future<void> login(String email, String password) =>
      _authenticate('/api/v1/auth/login', email, password);

  /// Creates an account and stores the token pair.
  Future<void> register(String email, String password) =>
      _authenticate('/api/v1/auth/register', email, password);

  Future<void> _authenticate(String path, String email, String password) async {
    final response = await _send(
      () => _http.post(
        _uri(path),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _errorFrom(response);
    }
    await tokenStore.write(_tokensFrom(response));
  }

  /// Ends this session. Local tokens are always removed, even when offline.
  Future<void> logout() async {
    final tokens = await tokenStore.read();
    await tokenStore.clear();
    if (tokens == null) {
      return;
    }
    try {
      await _send(
        () => _http.post(
          _uri('/api/v1/auth/logout'),
          headers: _jsonHeaders,
          body: jsonEncode({'refreshToken': tokens.refreshToken}),
        ),
      );
    } on ApiException {
      // The local session is already gone; the server token will expire on its own.
    }
  }

  /// Loads the signed-in user's tasks.
  Future<List<Task>> listTasks() async {
    final response = await _authorized(
      (headers) =>
          _http.get(_uri('/api/v1/tasks', {'limit': '100'}), headers: headers),
    );
    _expectStatus(response, 200);
    final raw = _decodeObject(response)['tasks'];
    if (raw is! List) {
      throw const ApiException(unexpectedMessage);
    }
    return [for (final item in raw) _parseTask(item)];
  }

  /// Creates a task.
  Future<Task> createTask(String title) async {
    final response = await _authorized(
      (headers) => _http.post(
        _uri('/api/v1/tasks'),
        headers: headers,
        body: jsonEncode({'title': title}),
      ),
    );
    _expectStatus(response, 201);
    return _parseTask(_decodeObject(response));
  }

  /// Updates a task's title and/or completion state.
  Future<Task> updateTask(String id, {String? title, bool? completed}) async {
    final response = await _authorized(
      (headers) => _http.patch(
        _uri('/api/v1/tasks/${Uri.encodeComponent(id)}'),
        headers: headers,
        body: jsonEncode({
          if (title != null) 'title': title,
          if (completed != null) 'completed': completed,
        }),
      ),
    );
    _expectStatus(response, 200);
    return _parseTask(_decodeObject(response));
  }

  /// Deletes a task.
  Future<void> deleteTask(String id) async {
    final response = await _authorized(
      (headers) => _http.delete(
        _uri('/api/v1/tasks/${Uri.encodeComponent(id)}'),
        headers: headers,
      ),
    );
    _expectStatus(response, 204);
  }

  /// Sends an authenticated request. On 401 it refreshes the token pair once and retries.
  Future<http.Response> _authorized(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final current = await tokenStore.read();
    if (current == null) {
      throw const UnauthorizedException();
    }

    final response = await _send(() => send(_authHeaders(current)));
    if (response.statusCode != 401) {
      return response;
    }

    final refreshed = await _refreshTokens(current);
    final retried = await _send(() => send(_authHeaders(refreshed)));
    if (retried.statusCode == 401) {
      await tokenStore.clear();
      throw const UnauthorizedException();
    }
    return retried;
  }

  /// Only one refresh runs at a time; parallel 401s share it. Refresh tokens are
  /// single-use on the server, so two parallel refreshes would look like token theft.
  Future<AuthTokens> _refreshTokens(AuthTokens stale) {
    return _refreshing ??=
        _doRefresh(stale).whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens> _doRefresh(AuthTokens stale) async {
    final latest = await tokenStore.read();
    if (latest == null) {
      throw const UnauthorizedException();
    }
    if (latest.accessToken != stale.accessToken) {
      // Another request already refreshed and stored the newest pair.
      return latest;
    }

    final response = await _send(
      () => _http.post(
        _uri('/api/v1/auth/refresh'),
        headers: _jsonHeaders,
        body: jsonEncode({'refreshToken': latest.refreshToken}),
      ),
    );
    if (response.statusCode != 200) {
      await tokenStore.clear();
      throw const UnauthorizedException();
    }

    final tokens = _tokensFrom(response);
    await tokenStore.write(tokens);
    return tokens;
  }

  Map<String, String> _authHeaders(AuthTokens tokens) => {
        ..._jsonHeaders,
        'Authorization': 'Bearer ${tokens.accessToken}',
      };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
          'The server took too long to respond. Try again.');
    } on http.ClientException {
      throw const ApiException(offlineMessage);
    }
  }

  void _expectStatus(http.Response response, int expected) {
    if (response.statusCode != expected) {
      throw _errorFrom(response);
    }
  }

  ApiException _errorFrom(http.Response response) {
    if (response.statusCode == 429) {
      return const ApiException('Too many attempts. Wait a moment and try again.',
          statusCode: 429);
    }
    if (response.statusCode >= 500) {
      return ApiException('The server had a problem. Try again later.',
          statusCode: response.statusCode);
    }
    String message = 'Something went wrong. Try again.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is String && error.isNotEmpty && error.length <= 200) {
          message = error;
        }
      }
    } on FormatException {
      // Keep the generic message.
    }
    return ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body;
      }
    } on FormatException {
      // Fall through.
    }
    throw const ApiException(unexpectedMessage);
  }

  Task _parseTask(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(unexpectedMessage);
    }
    try {
      return Task.fromJson(json);
    } on FormatException {
      throw const ApiException(unexpectedMessage);
    }
  }

  AuthTokens _tokensFrom(http.Response response) {
    final body = _decodeObject(response);
    final access = body['accessToken'];
    final refresh = body['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiException(unexpectedMessage);
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
