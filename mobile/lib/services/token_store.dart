/// An access/refresh token pair.
class AuthTokens {
  /// Creates a token pair.
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// Short-lived JWT sent as `Authorization: Bearer`.
  final String accessToken;

  /// Opaque token used once to obtain a new pair.
  final String refreshToken;
}

/// Persists the current session's tokens.
abstract class TokenStore {
  /// Returns the stored tokens, or `null` when signed out.
  Future<AuthTokens?> read();

  /// Replaces the stored tokens.
  Future<void> write(AuthTokens tokens);

  /// Removes the stored tokens.
  Future<void> clear();
}

/// Keeps tokens in memory. Used by tests; tokens disappear when the app closes.
class InMemoryTokenStore implements TokenStore {
  /// Creates a store, optionally already signed in.
  InMemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
