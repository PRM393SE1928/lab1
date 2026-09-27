import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/evaluation_report.dart';
import 'package:flutter_application_2/providers/app_state.dart';
import 'package:flutter_application_2/screens/report_screen.dart';
import 'package:flutter_application_2/services/export_service.dart';

class FakeExportService extends ExportService {
  String? destination = 'evaluation.xlsx';
  bool fail = false;
  int generations = 0, saves = 0;
  Completer<Uint8List>? gate;
  EvaluationReport? report;
  @override
  String get successMessage => 'Excel report saved.';
  @override
  Future<String?> chooseDestination(String suggestedName) async => destination;
  @override
  Future<Uint8List> generate(EvaluationReport snapshot) async {
    generations++;
    report = snapshot;
    return gate == null ? Uint8List.fromList([1]) : await gate!.future;
  }

  @override
  Future<void> save(Uint8List bytes, String destination) async {
    if (fail) throw StateError('Access denied');
    saves++;
  }
}

void main() {
  Future<AppState> mount(WidgetTester tester, FakeExportService service) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportScreen(state: state, exportService: service),
        ),
      ),
    );
    return state;
  }

  testWidgets(
    'Export button saves a detached report and prevents duplicate clicks',
    (tester) async {
      final service = FakeExportService()..gate = Completer<Uint8List>();
      final state = await mount(tester, service);
      await tester.tap(find.text('Export Excel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Export Excel'),
            )
            .onPressed,
        isNull,
      );
      expect(service.report!.testCases.length, state.testCases.length);
      service.gate!.complete(Uint8List.fromList([1]));
      await tester.pumpAndSettle();
      expect(service.saves, 1);
      expect(find.text('Excel report saved.'), findsOneWidget);
      expect(state.reviewed, 1);
    },
  );
  testWidgets(
    'Cancelling destination leaves workspace unchanged and generates nothing',
    (tester) async {
      final service = FakeExportService()..destination = null;
      final state = await mount(tester, service);
      final cases = state.testCases;
      await tester.tap(find.text('Export Excel'));
      await tester.pumpAndSettle();
      expect(find.text('Export cancelled.'), findsOneWidget);
      expect(service.generations, 0);
      expect(state.testCases, same(cases));
    },
  );
  testWidgets('Failure shows useful error and allows retry', (tester) async {
    final service = FakeExportService()..fail = true;
    final state = await mount(tester, service);
    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not export'), findsOneWidget);
    expect(state.reviewed, 1);
    service.fail = false;
    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();
    expect(service.saves, 1);
    expect(find.text('Excel report saved.'), findsOneWidget);
  });
  testWidgets('Export cannot overwrite the imported workbook', (tester) async {
    final service = FakeExportService()..destination = 'C:/project/source.xlsx';
    final state = await mount(tester, service);
    state.importedFilePath = 'C:/project/source.xlsx';
    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('must not be overwritten'), findsOneWidget);
    expect(service.saves, 0);
    expect(service.generations, 0);
  });
}
