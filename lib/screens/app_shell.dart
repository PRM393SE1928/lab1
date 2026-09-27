import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../widgets/app_sidebar.dart';
import 'dashboard_screen.dart';
import 'import_screen.dart';
import 'review_screen.dart';
import 'issues_screen.dart';
import 'report_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int page = 0;
  void openReview(String id) => setState(() {
    widget.state.selectTestCase(id);
    page = 2;
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              AppSidebar(
                selected: page,
                compact: constraints.maxWidth < 1050,
                onSelected: (value) => setState(() => page = value),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Text(
                        pageLabels[page],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        '${widget.state.hasImportedCases ? 'Imported: ${widget.state.importedFileName}' : 'Sample data'} · ${widget.state.storageStatus}',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                    if (widget.state.storageError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                widget.state.storageError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.state.flushWorkspace,
                              child: const Text('Retry saving'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: switch (page) {
                        0 => DashboardScreen(state: widget.state),
                        1 => ImportScreen(
                          state: widget.state,
                          onOpenReview: () =>
                              openReview(widget.state.selectedId),
                        ),
                        2 => ReviewScreen(
                          key: ValueKey(widget.state.workbookRevision),
                          state: widget.state,
                        ),
                        3 => IssuesScreen(
                          state: widget.state,
                          onOpen: openReview,
                        ),
                        _ => ReportScreen(state: widget.state),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
