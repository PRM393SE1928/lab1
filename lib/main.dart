import 'package:flutter/material.dart';

import 'providers/app_state.dart';
import 'screens/app_shell.dart';
import 'services/local_workspace.dart';
import 'services/workspace_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(storage: createWorkspaceStore()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.storage});
  final WorkspaceStore? storage;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppState state;
  @override
  void initState() {
    super.initState();
    state = AppState(storage: widget.storage);
    state.restoreWorkspace();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Test Case Analysis & Evaluation',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      scaffoldBackgroundColor: const Color(0xfff5f6fa),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.restoring) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring local workspace...'),
                ],
              ),
            ),
          );
        }
        if (state.restoreError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(state.restoreError!),
                    const SizedBox(height: 16),
                    const Text('Stored data has not been overwritten.'),
                    FilledButton(
                      onPressed: state.restoreWorkspace,
                      child: const Text('Retry loading'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return AppShell(state: state);
      },
    ),
  );
}
