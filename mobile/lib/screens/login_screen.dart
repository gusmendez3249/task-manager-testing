import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../validation.dart';

/// Sign-in and registration screen.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key, required this.api, required this.onSignedIn});

  /// API used to sign in or register.
  final ApiClient api;

  /// Called once after a successful sign-in or registration.
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _submitting = true;
    setState(() => _error = null);

    try {
      if (_registering) {
        await widget.api.register(_email.text, _password.text);
      } else {
        await widget.api.login(_email.text, _password.text);
      }
      if (mounted) {
        widget.onSignedIn();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      _submitting = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _registering ? 'Create account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('email-field'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('password-field'),
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText:
                              _registering ? '8 to 72 characters' : null,
                        ),
                        validator: validatePassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('auth-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('login-button'),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Signing in',
                                ),
                              )
                            : Text(title),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('register-toggle'),
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                  _registering = !_registering;
                                  _error = null;
                                }),
                        child: Text(
                          _registering
                              ? 'I already have an account'
                              : 'Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
