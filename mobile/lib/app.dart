import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/api_client.dart';

/// Root widget: shows the login screen or the task list depending on the session.
class TaskManagerApp extends StatefulWidget {
  /// Creates the app. Inject a fake-backed [api] in tests.
  const TaskManagerApp({super.key, required this.api});

  /// API client shared by every screen.
  final ApiClient api;

  @override
  State<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    widget.api.hasSession().then((value) {
      if (mounted) setState(() => _signedIn = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_signedIn == null) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
      );
    } else if (_signedIn!) {
      home = TaskListScreen(
        api: widget.api,
        onSignedOut: () => setState(() => _signedIn = false),
      );
    } else {
      home = LoginScreen(
        api: widget.api,
        onSignedIn: () => setState(() => _signedIn = true),
      );
    }

    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
