@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_sync_drift/offline_first_sync_drift.dart';
import 'package:provider/provider.dart';
import 'package:todo_advanced_frontend/models/todo.dart';
import 'package:todo_advanced_frontend/services/conflict_handler.dart';
import 'package:todo_advanced_frontend/ui/widgets/conflict_dialog.dart';

/// Widget tests for ConflictDialog.
///
/// These tests verify the conflict resolution UI works correctly.
/// Run with: `flutter test test/widget/ --tags widget`
void main() {
  late ConflictHandler conflictHandler;

  /// Creates a test conflict for testing purposes.
  ConflictInfo createTestConflict({
    String id = 'test-id',
    String localTitle = 'Local Title',
    String serverTitle = 'Server Title',
    bool localCompleted = false,
    bool serverCompleted = true,
    int localPriority = 3,
    int serverPriority = 1,
  }) {
    final now = DateTime.now().toUtc();
    return ConflictInfo(
      conflict: Conflict(
        kind: 'todos',
        entityId: id,
        opId: 'op-123',
        localData: {
          'id': id,
          'title': localTitle,
          'completed': localCompleted,
          'priority': localPriority,
          'updated_at': now.toIso8601String(),
        },
        serverData: {
          'id': id,
          'title': serverTitle,
          'completed': serverCompleted,
          'priority': serverPriority,
          'updated_at': now.toIso8601String(),
        },
        localTimestamp: now,
        serverTimestamp: now,
      ),
      localTodo: Todo(
        id: id,
        title: localTitle,
        completed: localCompleted,
        priority: localPriority,
        updatedAt: now,
      ),
      serverTodo: Todo(
        id: id,
        title: serverTitle,
        completed: serverCompleted,
        priority: serverPriority,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    conflictHandler = ConflictHandler();
  });

  tearDown(() {
    conflictHandler.dispose();
  });

  Widget createApp(ConflictInfo conflict) {
    return MaterialApp(
      home: ChangeNotifierProvider<ConflictHandler>.value(
        value: conflictHandler,
        child: Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              child: ConflictDialog(conflict: conflict),
            ),
          ),
        ),
      ),
    );
  }

  group('ConflictDialog Widget Tests', () {
    testWidgets('shows conflict title and warning icon', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      expect(find.text('Sync Conflict'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('shows local and server titles in diff', (tester) async {
      final conflict = createTestConflict(
        localTitle: 'My Local Title',
        serverTitle: 'My Server Title',
      );
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // The dialog should display both versions
      expect(find.textContaining('My Local Title'), findsWidgets);
      expect(find.textContaining('My Server Title'), findsWidgets);
    });

    testWidgets('shows all resolution buttons', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      expect(find.text('Use Local'), findsOneWidget);
      expect(find.text('Use Server'), findsOneWidget);
      expect(find.text('Merge'), findsOneWidget);
    });

    testWidgets('Use Local button calls resolveWithLocal', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Simulate the handler having this conflict
      conflictHandler.resolve(conflict.conflict);
      await tester.pump();

      await tester.tap(find.text('Use Local'));
      await tester.pumpAndSettle();

      // The conflict should be resolved
      expect(conflictHandler.hasConflicts, isFalse);
    });

    testWidgets('Use Server button calls resolveWithServer', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Simulate the handler having this conflict
      conflictHandler.resolve(conflict.conflict);
      await tester.pump();

      await tester.tap(find.text('Use Server'));
      await tester.pumpAndSettle();

      // The conflict should be resolved
      expect(conflictHandler.hasConflicts, isFalse);
    });

    testWidgets('Merge button shows merge editor', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Initially merge editor is hidden
      expect(find.text('Merge Editor'), findsNothing);

      // Tap Merge button
      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();

      // Merge editor should appear
      expect(find.text('Merge Editor'), findsOneWidget);
    });

    testWidgets('shows conflicting fields indicator', (tester) async {
      final conflict = createTestConflict(
        localTitle: 'Title A',
        serverTitle: 'Title B',
        localPriority: 1,
        serverPriority: 5,
      );
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Should show that title and priority differ
      expect(find.textContaining('Title'), findsWidgets);
      expect(find.textContaining('Priority'), findsWidgets);
    });

    testWidgets('prevents double-tap on resolution buttons', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Simulate the handler having this conflict
      conflictHandler.resolve(conflict.conflict);
      await tester.pump();

      // Tap Use Local
      await tester.tap(find.text('Use Local'));

      // Immediately try to tap Use Server
      await tester.tap(find.text('Use Server'));
      await tester.pumpAndSettle();

      // Should not crash and conflict should be resolved
      expect(conflictHandler.hasConflicts, isFalse);
    });

    testWidgets('shows phone icon for local button', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Multiple phone icons may appear (button + diff viewer)
      expect(find.byIcon(Icons.phone_android), findsAtLeastNWidgets(1));
    });

    testWidgets('shows cloud icon for server button', (tester) async {
      final conflict = createTestConflict();
      await tester.pumpWidget(createApp(conflict));
      await tester.pumpAndSettle();

      // Multiple cloud icons may appear (button + diff viewer)
      expect(find.byIcon(Icons.cloud_download), findsAtLeastNWidgets(1));
    });
  });
}
