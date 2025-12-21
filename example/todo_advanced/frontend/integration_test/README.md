# Integration Tests: Advanced Offline-First Architecture

> **Purpose**: Verify advanced offline-first architecture with priority fields, ConflictHandler, and server simulation.

## Table of Contents

- [Quick Start](#quick-start)
- [Simple vs Advanced](#simple-vs-advanced)
- [Architecture](#architecture)
- [Test Structure](#test-structure)
- [ConflictHandler](#conflicthandler)
- [Priority Field](#priority-field)
- [Test Patterns](#test-patterns)
- [Running Tests](#running-tests)
- [Expected Output](#expected-output)
- [Best Practices](#best-practices)
- [Common Mistakes](#common-mistakes)
- [Troubleshooting](#troubleshooting)
- [PR Checklist](#pr-checklist)

---

## Quick Start

```bash
# Offline tests (NO backend required)
flutter test integration_test/offline_test.dart

# Network recovery tests (backend required)
cd ../backend && dart_frog dev &
cd ../frontend && flutter test integration_test/network_recovery_test.dart
```

---

## Simple vs Advanced

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FEATURE COMPARISON                               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  todo_simple                         todo_advanced                      │
│  ────────────                        ─────────────                      │
│                                                                         │
│  Todo Model:                         Todo Model:                        │
│  ┌─────────────────┐                 ┌─────────────────┐               │
│  │ • id            │                 │ • id            │               │
│  │ • title         │                 │ • title         │               │
│  │ • completed     │                 │ • completed     │               │
│  │                 │                 │ • priority      │ ← NEW (1-5)   │
│  │                 │                 │ • description   │ ← NEW         │
│  └─────────────────┘                 └─────────────────┘               │
│                                                                         │
│  SyncService:                        SyncService:                       │
│  ┌─────────────────┐                 ┌─────────────────┐               │
│  │ • sync()        │                 │ • sync()        │               │
│  │ • getPending()  │                 │ • getPending()  │               │
│  │                 │                 │ • conflictHandler│ ← NEW        │
│  └─────────────────┘                 └─────────────────┘               │
│                                                                         │
│  UI Components:                      UI Components:                     │
│  ┌─────────────────┐                 ┌─────────────────┐               │
│  │ • TodoListScreen│                 │ • TodoListScreen│               │
│  │ • Sync button   │                 │ • Sync button   │               │
│  │                 │                 │ • Simulation 🧪 │ ← NEW         │
│  │                 │                 │ • Priority slider│ ← NEW        │
│  │                 │                 │ • Conflict dialog│ ← NEW        │
│  └─────────────────┘                 └─────────────────┘               │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

| Feature | todo_simple | todo_advanced |
|---------|:-----------:|:-------------:|
| Priority field (1-5) | ❌ | ✅ |
| Description field | ❌ | ✅ |
| ConflictHandler | ❌ | ✅ |
| Event logging | ❌ | ✅ |
| Server simulation | ❌ | ✅ |
| Conflict resolution UI | ❌ | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   ADVANCED OFFLINE-FIRST ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         ┌─────────────────────┐                         │
│                         │         UI          │                         │
│                         │  ┌───────────────┐  │                         │
│                         │  │ Priority [━━━]│  │ ← Slider 1-5            │
│                         │  └───────────────┘  │                         │
│                         │  ┌───────────────┐  │                         │
│                         │  │ 🧪 Simulate   │  │ ← Server controls       │
│                         │  └───────────────┘  │                         │
│                         └──────────┬──────────┘                         │
│                                    │                                    │
│                                    ▼                                    │
│                         ┌─────────────────────┐                         │
│                         │     Repository      │                         │
│                         └──────────┬──────────┘                         │
│                                    │                                    │
│            ┌───────────────────────┼───────────────────────┐            │
│            │                       │                       │            │
│            ▼                       ▼                       ▼            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │    Local DB     │    │   SyncService   │    │ ConflictHandler │     │
│  │     (Drift)     │    │                 │    │                 │     │
│  │                 │    │  ┌───────────┐  │    │  ┌───────────┐  │     │
│  │  ┌───────────┐  │◄───│  │  Outbox   │  │    │  │ Event Log │  │     │
│  │  │   Todos   │  │    │  └───────────┘  │    │  └───────────┘  │     │
│  │  │ +priority │  │    │        │        │    │        │        │     │
│  │  └───────────┘  │    │        ▼        │    │        ▼        │     │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │     │
│  │  │  Outbox   │  │    │  │   HTTP    │  │───▶│  │ Conflict  │  │     │
│  │  └───────────┘  │    │  │  Client   │  │    │  │  Dialog   │  │     │
│  └─────────────────┘    │  └───────────┘  │    │  └───────────┘  │     │
│                         └────────┬────────┘    └─────────────────┘     │
│                                  │                                      │
│                                  ▼                                      │
│                       ┌─────────────────────┐                          │
│                       │       Server        │                          │
│                       │  ┌───────────────┐  │                          │
│                       │  │   REST API    │  │                          │
│                       │  └───────────────┘  │                          │
│                       │  ┌───────────────┐  │                          │
│                       │  │  Simulation   │  │ ← /simulate/* endpoints  │
│                       │  └───────────────┘  │                          │
│                       └─────────────────────┘                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Sync Flow with ConflictHandler

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      SYNC OPERATION FLOW                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Outbox                                                                │
│     │                                                                   │
│     ▼                                                                   │
│  ┌───────┐    ┌───────┐    ┌───────┐    ┌────────────────┐             │
│  │ Push  │───▶│ HTTP  │───▶│Server │───▶│    Response    │             │
│  │ sync  │    │  PUT  │    │       │    └───────┬────────┘             │
│  └───────┘    └───────┘    └───────┘            │                      │
│                                                  │                      │
│                          ┌───────────────────────┴───────────────────┐  │
│                          │                                           │  │
│                          ▼                                           ▼  │
│                   ┌─────────────┐                           ┌───────────┐
│                   │   SUCCESS   │                           │ CONFLICT  │
│                   │             │                           │           │
│                   │ Log: "✓"    │                           │ Log: "⚠️" │
│                   │ Status: OK  │                           │ Show UI   │
│                   └─────────────┘                           └─────┬─────┘
│                                                                   │     │
│                                                                   ▼     │
│                                                          ┌─────────────┐│
│                                                          │  Conflict   ││
│                                                          │   Dialog    ││
│                                                          │             ││
│                                                          │ Keep Local  ││
│                                                          │ Keep Remote ││
│                                                          │ Merge       ││
│                                                          └─────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Test Structure

```
integration_test/
├── README.md                   # ← This file
├── offline_test.dart           # Tests without server (15 tests)
└── network_recovery_test.dart  # Tests with server (10 tests)
```

### offline_test.dart

| Group | Test | What it verifies |
|-------|------|------------------|
| **App Launch** | launches with all UI | UI + simulation button |
| **CRUD** | CREATE with description | Description field |
| **CRUD** | CREATE with priority | Priority slider |
| **CRUD** | UPDATE preserves fields | All fields maintained |
| **CRUD** | DELETE confirmation | Confirmation dialog |
| **CRUD** | TOGGLE visual feedback | Strikethrough |
| **Sync Error** | cloud_off icon | Error icon displayed |
| **Sync Error** | retry works | Retry after error |
| **Sync Error** | status transitions | idle → syncing → error |
| **Sync Error** | simulation accessible | 🧪 button works |
| **ConflictHandler** | logs sync error | Errors logged |
| **ConflictHandler** | stores entries | Manual logging API |
| **Outbox** | different priorities | Priority queueing |
| **Outbox** | chained operations | CREATE→EDIT→TOGGLE |
| **Empty State** | preserved after error | Empty screen stable |

### network_recovery_test.dart

| Group | Test | What it verifies |
|-------|------|------------------|
| **Basic Ops** | CREATE | Todos sync on recovery |
| **Basic Ops** | UPDATE | Edits sync on recovery |
| **Basic Ops** | DELETE | Deletions sync on recovery |
| **Basic Ops** | TOGGLE | Completion syncs on recovery |
| **Basic Ops** | PRIORITY | Priority changes sync |
| **Complex** | multiple periods | Online→Offline→Online |
| **Complex** | mixed + priority | Combined operations |
| **UI State** | status indicator | "Online" after recovery |
| **UI State** | optimistic UI | Todos visible before sync |
| **ConflictHandler** | logs events | Sync events logged |

---

## ConflictHandler

### Purpose

ConflictHandler is the central component for:
- 📝 Logging all sync events
- ⚠️ Detecting conflicts (concurrent edits)
- 🔧 Providing UI for conflict resolution

### API Reference

```dart
// Initialization
final conflictHandler = ConflictHandler();

// Logging events
conflictHandler.logEvent('Sync started');
conflictHandler.logEvent('Pushed 5 todos successfully');
conflictHandler.logEvent('Conflict detected: Todo #123');

// Reading logs
for (final entry in conflictHandler.log) {
  print('[${entry.timestamp}] ${entry.message}');
}

// Clearing logs
conflictHandler.clearLog();

// Dispose (required!)
conflictHandler.dispose();
```

### Event Types

```dart
// ✅ Success events
conflictHandler.logEvent('Sync completed: pushed 3 todos');
conflictHandler.logEvent('Pull completed: received 5 updates');

// ❌ Error events
conflictHandler.logEvent('Sync failed: network error');
conflictHandler.logEvent('Server returned 500: Internal Error');

// ⚠️ Conflict events
conflictHandler.logEvent('Conflict detected: Todo "Buy milk"');
conflictHandler.logEvent('Resolution: kept local version');
conflictHandler.logEvent('Resolution: merged changes');
```

### Testing ConflictHandler

```dart
testWidgets('logs sync events during recovery', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  // Clear previous logs
  conflictHandler.clearLog();

  // Create and sync
  await repo.create(title: 'Test');
  await syncService.sync();

  // Verify logging
  expect(conflictHandler.log, isNotEmpty);

  final hasSyncLog = conflictHandler.log.any(
    (entry) => entry.message.toLowerCase().contains('sync'),
  );
  expect(hasSyncLog, isTrue);
});
```

---

## Priority Field

### Priority Scale

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PRIORITY SCALE                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│     1          2          3          4          5                       │
│     │          │          │          │          │                       │
│     ▼          ▼          ▼          ▼          ▼                       │
│   ┌───┐      ┌───┐      ┌───┐      ┌───┐      ┌───┐                    │
│   │🟢│      │🟡│      │🟠│      │🔴│      │🔥│                    │
│   └───┘      └───┘      └───┘      └───┘      └───┘                    │
│    Low     Medium-    Medium    Medium-     High                        │
│             Low                   High                                  │
│                                                                         │
│   Examples:                                                             │
│   • 1 = "Nice to have"                                                 │
│   • 3 = "Should do this week"                                          │
│   • 5 = "Urgent, do now!"                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### API Reference

```dart
// Create with priority
await repo.create(title: 'Urgent task', priority: 5);
await repo.create(title: 'Normal task', priority: 3);
await repo.create(title: 'Low priority', priority: 1);

// Update priority
await repo.update(todo, priority: 4);

// Get priority
final priority = todo.priority;  // 1-5
```

### UI Testing with Priority

```dart
testWidgets('CREATE: todo with priority works', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  // Open create form
  await tester.tap(find.text('Add Todo'));
  await tester.pumpAndSettle();

  // Enter title
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Title'),
    'High priority task',
  );

  // Set priority via slider
  final slider = find.byType(Slider);
  if (slider.evaluate().isNotEmpty) {
    await tester.drag(slider, const Offset(100, 0));  // Right = higher
  }

  // Save
  await tester.tap(find.byTooltip('Save'));
  await tester.pumpAndSettle();

  expect(find.text('High priority task'), findsOneWidget);
});
```

### Helper with Priority

```dart
/// Creates a todo with priority and syncs immediately
Future<Todo> createAndSync(String title, {int priority = 1}) async {
  final todo = await repo.create(title: title, priority: priority);
  final stats = await syncService.sync();
  expect(stats.pushed, greaterThan(0));
  return todo;
}

// Usage
final urgent = await createAndSync('Fix critical bug', priority: 5);
final normal = await createAndSync('Review PR', priority: 3);
final low = await createAndSync('Update docs', priority: 1);
```

---

## Test Patterns

### 1. Provider Setup (Advanced)

```dart
Widget buildTestApp() {
  return MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      Provider<TodoRepository>.value(value: repo),
      // ConflictHandler is ChangeNotifier!
      ChangeNotifierProvider<ConflictHandler>.value(value: conflictHandler),
      ChangeNotifierProvider<SyncService>.value(value: syncService),
    ],
    child: MaterialApp(
      home: const TodoListScreen(),
      theme: ThemeData(useMaterial3: true),
    ),
  );
}
```

### 2. SetUp/TearDown (Advanced)

```dart
late AppDatabase db;
late TodoRepository repo;
late ConflictHandler conflictHandler;  // ← Advanced
late SyncService syncService;

setUp(() {
  db = AppDatabase(NativeDatabase.memory());
  repo = TodoRepository(db);
  conflictHandler = ConflictHandler();  // ← Create

  syncService = SyncService(
    db: db,
    baseUrl: 'http://localhost:99999',
    conflictHandler: conflictHandler,   // ← Pass it!
    maxRetries: 0,
  );
});

tearDown(() async {
  syncService.dispose();
  conflictHandler.dispose();  // ← Required!
  await db.close();
});
```

### 3. Three-Phase Pattern with Priority

```dart
testWidgets('PRIORITY: changes sync on recovery', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 1: ONLINE                                                    ║
  // ║ Create todo with low priority                                      ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  final title = uniqueName('Priority');
  final todo = await createAndSync(title, priority: 1);

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 2: OFFLINE                                                   ║
  // ║ Change to high priority without syncing                            ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  await repo.update(todo, priority: 5);
  await expectPending(1);

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 3: RECOVERY                                                  ║
  // ║ Sync — priority change should persist                              ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  await syncAndVerify(expectedPushed: 1);

  // Verify priority persisted
  final updated = (await repo.getAll()).firstWhere((t) => t.title == title);
  expect(updated.priority, 5);
});
```

---

## Running Tests

### Offline Tests

```bash
# iOS Simulator
flutter test integration_test/offline_test.dart

# Verbose output
flutter test integration_test/offline_test.dart --reporter expanded

# Specific test
flutter test integration_test/offline_test.dart --name "priority"
```

### Network Recovery Tests

```bash
# Terminal 1: Backend
cd ../backend
dart_frog dev

# Terminal 2: Tests
cd ../frontend
flutter test integration_test/network_recovery_test.dart
```

### All Tests

```bash
flutter test integration_test/
```

---

## Expected Output

### offline_test.dart (Success)

```
00:00 +0: loading /integration_test/offline_test.dart
00:02 +0: Offline Mode (Advanced) App Launch launches with all UI elements
00:03 +1: Offline Mode (Advanced) CRUD Operations CREATE: todo with description
00:04 +2: Offline Mode (Advanced) CRUD Operations CREATE: todo with priority
00:05 +3: Offline Mode (Advanced) CRUD Operations UPDATE: edit preserves all fields
00:06 +4: Offline Mode (Advanced) CRUD Operations DELETE: confirmation dialog
00:07 +5: Offline Mode (Advanced) CRUD Operations TOGGLE: completion with feedback
00:09 +6: Offline Mode (Advanced) Sync Error Handling shows error with cloud_off
00:10 +7: Offline Mode (Advanced) Sync Error Handling retry works after error
00:12 +8: Offline Mode (Advanced) Sync Error Handling status transitions
00:13 +9: Offline Mode (Advanced) Sync Error Handling simulation button accessible
00:14 +10: Offline Mode (Advanced) ConflictHandler logs sync error
00:15 +11: Offline Mode (Advanced) ConflictHandler stores manual log entries
00:16 +12: Offline Mode (Advanced) Outbox Queue todos with different priorities
00:17 +13: Offline Mode (Advanced) Outbox Queue chained operations persist
00:18 +14: Offline Mode (Advanced) Empty State preserved after sync error

All 15 tests passed!
```

### network_recovery_test.dart (Success)

```
00:00 +0: Network Recovery (Advanced) Basic Operations CREATE: sync on recovery
00:02 +1: Network Recovery (Advanced) Basic Operations UPDATE: sync on recovery
00:03 +2: Network Recovery (Advanced) Basic Operations DELETE: sync on recovery
00:04 +3: Network Recovery (Advanced) Basic Operations TOGGLE: sync on recovery
00:05 +4: Network Recovery (Advanced) Basic Operations PRIORITY: sync on recovery
00:07 +5: Network Recovery (Advanced) Complex Scenarios multiple offline periods
00:09 +6: Network Recovery (Advanced) Complex Scenarios mixed operations + priority
00:10 +7: Network Recovery (Advanced) UI State status indicator shows Online
00:11 +8: Network Recovery (Advanced) UI State todos with priority visible
00:12 +9: Network Recovery (Advanced) ConflictHandler logs sync events

All 10 tests passed!
```

---

## Best Practices

### 1. Always Pass ConflictHandler

```dart
// ✅ GOOD: ConflictHandler passed to SyncService
syncService = SyncService(
  db: db,
  baseUrl: url,
  conflictHandler: conflictHandler,  // ← Required for logging
);

// ❌ BAD: Missing ConflictHandler
syncService = SyncService(db: db, baseUrl: url);
// Logs won't work!
```

### 2. Dispose ChangeNotifiers

```dart
// ✅ GOOD: Proper disposal order
tearDown(() async {
  syncService.dispose();       // First: may have timers
  conflictHandler.dispose();   // Second: ChangeNotifier
  await db.close();            // Last: database
});

// ❌ BAD: Missing dispose
tearDown(() async {
  await db.close();
  // Missing: syncService.dispose()
  // Missing: conflictHandler.dispose()
  // Result: Memory leak, "Timer still pending" warning
});
```

### 3. Clear Logs Before Checking

```dart
// ✅ GOOD: Clear before test
conflictHandler.clearLog();
await syncService.sync();
expect(conflictHandler.log, isNotEmpty);  // Only this sync's logs

// ❌ BAD: Logs from previous operations
await syncService.sync();
expect(conflictHandler.log.length, 1);  // May have old logs!
```

### 4. Test Priority as Separate Field

```dart
// ✅ GOOD: Verify priority specifically
final updated = (await repo.getAll()).firstWhere((t) => t.title == title);
expect(updated.priority, 5);  // Explicit check

// ❌ BAD: Assume priority is synced
await syncAndVerify(expectedPushed: 1);
// Priority might not have synced correctly!
```

### 5. Use createAndSync with Priority

```dart
// ✅ GOOD: Helper with priority parameter
final todo = await createAndSync('Task', priority: 5);

// ❌ BAD: Separate create and sync
await repo.create(title: 'Task', priority: 5);
await syncService.sync();
// More verbose, harder to read
```

---

## Common Mistakes

### 1. Forgetting ConflictHandler

```dart
// ❌ WRONG: ConflictHandler not passed
syncService = SyncService(db: db, baseUrl: url);
// Later...
expect(conflictHandler.log, isNotEmpty);  // Fails! No logs recorded

// ✅ CORRECT
syncService = SyncService(
  db: db,
  baseUrl: url,
  conflictHandler: conflictHandler,
);
```

### 2. Not Disposing ConflictHandler

```dart
// ❌ WRONG: Memory leak
tearDown(() async {
  syncService.dispose();
  await db.close();
  // Missing: conflictHandler.dispose()
});

// ✅ CORRECT
tearDown(() async {
  syncService.dispose();
  conflictHandler.dispose();
  await db.close();
});
```

### 3. Priority Default Confusion

```dart
// ❌ WRONG: Assuming priority is 0
await repo.create(title: 'Task');  // priority defaults to 1, not 0!
expect(todo.priority, 0);  // Fails!

// ✅ CORRECT
await repo.create(title: 'Task');  // priority = 1
expect(todo.priority, 1);
```

### 4. Missing pumpAndSettle After Priority Change

```dart
// ❌ WRONG: UI not updated
await repo.update(todo, priority: 5);
expect(find.byIcon(Icons.priority_high), findsOneWidget);  // May fail!

// ✅ CORRECT
await repo.update(todo, priority: 5);
await tester.pumpAndSettle();  // Wait for UI
expect(find.byIcon(Icons.priority_high), findsOneWidget);
```

### 5. Checking Logs Too Early

```dart
// ❌ WRONG: Check before sync completes
syncService.sync();  // Not awaited!
expect(conflictHandler.log, isNotEmpty);  // Fails!

// ✅ CORRECT
await syncService.sync();
expect(conflictHandler.log, isNotEmpty);
```

---

## Troubleshooting

### ConflictHandler Not Logging

```dart
// Problem: conflictHandler.log is empty
// Cause 1: Not passed to SyncService

// ❌ Wrong
syncService = SyncService(db: db, baseUrl: url);

// ✅ Correct
syncService = SyncService(
  db: db,
  baseUrl: url,
  conflictHandler: conflictHandler,
);

// Cause 2: Not cleared before check
conflictHandler.clearLog();
await syncService.sync();
expect(conflictHandler.log, isNotEmpty);
```

### Priority Not Saving

```dart
// Problem: priority always 1
// Cause: Not passed to repo.create()

// ❌ Wrong
await repo.create(title: 'Task');  // priority = 1 by default

// ✅ Correct
await repo.create(title: 'Task', priority: 5);
```

### Simulation Button Not Working

```bash
# Problem: Tapping 🧪 does nothing
# Cause: Backend not running

# Check backend
curl http://localhost:8080/simulate/prioritize

# Start if not working
cd ../backend && dart_frog dev
```

### Tests Hang on pumpAndSettle

```dart
// Problem: Infinite loop
// Cause: ChangeNotifier not disposed

tearDown(() async {
  syncService.dispose();       // ← 1
  conflictHandler.dispose();   // ← 2
  await db.close();            // ← 3
});
```

### "Timer still pending" Warning

```dart
// Problem: Resource not disposed
// Solution: Dispose in correct order

tearDown(() async {
  // First: SyncService (may have timers)
  syncService.dispose();

  // Second: ConflictHandler (ChangeNotifier)
  conflictHandler.dispose();

  // Last: Database
  await db.close();
});
```

---

## PR Checklist

Before creating a PR:

- [ ] `flutter test integration_test/offline_test.dart` — all pass
- [ ] `flutter test integration_test/network_recovery_test.dart` — all pass (with backend)
- [ ] `flutter analyze` — no errors
- [ ] ConflictHandler passed to SyncService
- [ ] `tearDown()` calls `dispose()` for all ChangeNotifiers
- [ ] Priority tests use `createAndSync` with priority parameter
- [ ] `uniqueName()` used for all test data
- [ ] Logs cleared before checking ConflictHandler
- [ ] All operations followed by `pumpAndSettle()`

---

## Related Links

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Drift Database](https://drift.simonbinder.eu/)
- [Provider Package](https://pub.dev/packages/provider)
- [Offline-First Architecture](https://offlinefirst.org/)
- [Conflict Resolution Patterns](https://www.martinfowler.com/articles/patterns-of-distributed-systems/conflict-resolution.html)

---

*Last updated: December 2025*
