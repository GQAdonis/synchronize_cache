# Integration Tests: Offline-First Architecture

> **Purpose**: Verify offline-first architecture — the app works without network and syncs when connectivity is restored.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Test Structure](#test-structure)
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

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      OFFLINE-FIRST ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                              ┌──────────┐                               │
│                              │    UI    │                               │
│                              └────┬─────┘                               │
│                                   │                                     │
│                                   ▼                                     │
│                            ┌────────────┐                               │
│                            │ Repository │                               │
│                            └─────┬──────┘                               │
│                                  │                                      │
│                    ┌─────────────┴─────────────┐                        │
│                    │                           │                        │
│                    ▼                           ▼                        │
│            ┌─────────────┐             ┌─────────────┐                  │
│            │  Local DB   │             │ SyncService │                  │
│            │   (Drift)   │             │             │                  │
│            │             │◄────────────│  ┌───────┐  │                  │
│            │ ┌─────────┐ │             │  │Outbox │  │                  │
│            │ │  Todos  │ │             │  │Queue  │  │                  │
│            │ └─────────┘ │             │  └───┬───┘  │                  │
│            │ ┌─────────┐ │             │      │      │                  │
│            │ │ Outbox  │ │             │      ▼      │                  │
│            │ └─────────┘ │             │  ┌───────┐  │                  │
│            └─────────────┘             │  │ HTTP  │  │                  │
│                                        │  └───┬───┘  │                  │
│                                        └──────│──────┘                  │
│                                               │                         │
│                                               ▼                         │
│                                        ┌─────────────┐                  │
│                                        │   Server    │                  │
│                                        │  (REST API) │                  │
│                                        └─────────────┘                  │
│                                                                         │
│  KEY PRINCIPLE:                                                         │
│    User Action → Repository → Local DB → UI (instant)                   │
│                      ↓                                                  │
│                   Outbox → Server (background, when available)          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CREATE TODO FLOW                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   User taps "Add"                                                       │
│         │                                                               │
│         ▼                                                               │
│   ┌───────────┐    ┌───────────┐    ┌───────────┐                      │
│   │   Repo    │───▶│  Local DB │───▶│    UI     │   ← INSTANT (~5ms)   │
│   │  create() │    │  INSERT   │    │  refresh  │                      │
│   └─────┬─────┘    └───────────┘    └───────────┘                      │
│         │                                                               │
│         ▼                                                               │
│   ┌───────────┐    ┌───────────┐    ┌───────────┐                      │
│   │  Outbox   │───▶│   Sync    │───▶│  Server   │   ← BACKGROUND       │
│   │   queue   │    │   push    │    │   PUT     │     (when online)    │
│   └───────────┘    └───────────┘    └───────────┘                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Test Structure

```
integration_test/
├── README.md                   # ← This file
├── offline_test.dart           # Tests without server (11 tests)
└── network_recovery_test.dart  # Tests with server (8 tests)
```

### offline_test.dart

Tests app functionality when server is **completely unavailable**.

| Group | Test | What it verifies |
|-------|------|------------------|
| **App Launch** | launches and shows UI | UI renders without server |
| **CRUD** | CREATE | Todo appears instantly |
| **CRUD** | UPDATE | Changes reflected immediately |
| **CRUD** | DELETE | Deletion with confirmation |
| **CRUD** | TOGGLE | Checkbox + strikethrough |
| **Sync Error** | shows error status | `cloud_off` icon displayed |
| **Sync Error** | button functional | Retry works after error |
| **Sync Error** | status transitions | idle → syncing → error |
| **Outbox** | multiple operations | 3 todos = 3 queued |
| **Outbox** | chained operations | CREATE→EDIT→TOGGLE works |
| **Empty State** | preserved after error | Empty screen stable |

### network_recovery_test.dart

Tests the complete **offline → online sync cycle**.

| Group | Test | What it verifies |
|-------|------|------------------|
| **Basic Ops** | CREATE | Offline todos sync on recovery |
| **Basic Ops** | UPDATE | Edits sync on recovery |
| **Basic Ops** | DELETE | Deletions sync on recovery |
| **Basic Ops** | TOGGLE | Completion syncs on recovery |
| **Complex** | multiple periods | Online→Offline→Online→Offline |
| **Complex** | mixed operations | CREATE + EDIT + TOGGLE together |
| **UI State** | status indicator | Shows "Online" after recovery |
| **UI State** | optimistic UI | Todos visible before sync |

---

## Test Patterns

### 1. Simulating Offline Mode

```dart
// ❌ DON'T: Mock HttpClient, NetworkInfo, etc.
// ✅ DO: Use invalid URL = guaranteed failure

syncService = SyncService(
  db: db,
  baseUrl: 'http://localhost:99999', // Port doesn't exist
  maxRetries: 0,                      // No retries = fast tests
);
```

**Why this approach:**
- No mocks needed
- Tests real code paths
- Guaranteed network error
- Simple and reliable

### 2. Unique Test Names

```dart
// Avoid conflicts between test runs
String uniqueName(String base) =>
    '$base-${DateTime.now().millisecondsSinceEpoch}';

// Usage
final todo = uniqueName('Task');  // → "Task-1703089234567"
```

### 3. Helper Methods

```dart
/// Creates a todo and syncs immediately (ONLINE phase)
Future<Todo> createAndSync(String title) async {
  final todo = await repo.create(title: title);
  final stats = await syncService.sync();
  expect(stats.pushed, greaterThan(0));
  return todo;
}

/// Verifies outbox queue count
Future<void> expectPending(int count) async {
  expect(await syncService.getPendingCount(), count);
}

/// Syncs and verifies success (RECOVERY phase)
Future<void> syncAndVerify({int expectedPushed = 0}) async {
  final stats = await syncService.sync();
  if (expectedPushed > 0) {
    expect(stats.pushed, expectedPushed);
  }
  expect(syncService.status, SyncStatus.idle);
  expect(await syncService.getPendingCount(), 0);
}
```

### 4. Three-Phase Pattern

```dart
testWidgets('CREATE: offline todos sync on recovery', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 1: ONLINE                                                    ║
  // ║ Create baseline data, sync to server                               ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  final online = uniqueName('Online');
  await repo.create(title: online);
  await syncAndVerify(expectedPushed: 1);

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 2: OFFLINE                                                   ║
  // ║ Create WITHOUT calling sync() — simulates network down             ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  final offline = uniqueName('Offline');
  await repo.create(title: offline);

  // UI shows immediately (optimistic)
  expect(find.text(offline), findsOneWidget);
  // But waiting in outbox
  await expectPending(1);

  // ╔═══════════════════════════════════════════════════════════════════╗
  // ║ PHASE 3: RECOVERY                                                  ║
  // ║ Network "restored" — sync pushes queued operations                 ║
  // ╚═══════════════════════════════════════════════════════════════════╝
  await syncAndVerify(expectedPushed: 1);

  // All synced
  expect(find.text(online), findsOneWidget);
  expect(find.text(offline), findsOneWidget);
});
```

---

## Running Tests

### Offline Tests

```bash
# macOS/iOS Simulator
flutter test integration_test/offline_test.dart

# Specific device
flutter test integration_test/offline_test.dart -d "iPhone 15"

# Android Emulator
flutter test integration_test/offline_test.dart -d android

# Verbose output
flutter test integration_test/offline_test.dart --reporter expanded

# Run specific test
flutter test integration_test/offline_test.dart --name "CREATE"
```

### Network Recovery Tests

```bash
# Terminal 1: Start backend
cd ../backend
dart_frog dev

# Terminal 2: Run tests
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
00:02 +0: Offline Mode App Launch launches and shows UI when server unavailable
00:03 +1: Offline Mode CRUD Operations CREATE: todo appears immediately in UI
00:04 +2: Offline Mode CRUD Operations UPDATE: changes reflected immediately
00:05 +3: Offline Mode CRUD Operations DELETE: todo removed immediately
00:06 +4: Offline Mode CRUD Operations TOGGLE: completion state changes immediately
00:08 +5: Offline Mode Sync Error Handling shows error status after failed sync attempt
00:09 +6: Offline Mode Sync Error Handling sync button remains functional after error
00:11 +7: Offline Mode Sync Error Handling status transitions correctly: idle → syncing → error
00:12 +8: Offline Mode Outbox Queue multiple operations queue correctly
00:13 +9: Offline Mode Outbox Queue chained operations (create → edit → toggle) persist
00:14 +10: Offline Mode Empty State empty state preserved after sync error

All 11 tests passed!
```

### network_recovery_test.dart (Success)

```
00:00 +0: Network Recovery Basic Operations CREATE: todos created offline sync on recovery
00:02 +1: Network Recovery Basic Operations UPDATE: edits made offline sync on recovery
00:03 +2: Network Recovery Basic Operations DELETE: deletions made offline sync on recovery
00:04 +3: Network Recovery Basic Operations TOGGLE: completion changes sync on recovery
00:06 +4: Network Recovery Complex Scenarios multiple offline periods handled correctly
00:08 +5: Network Recovery Complex Scenarios mixed operations in single offline period
00:09 +6: Network Recovery UI State status indicator shows Online after recovery
00:10 +7: Network Recovery UI State todos visible immediately during offline (optimistic UI)

All 8 tests passed!
```

---

## Best Practices

### 1. Test Isolation

```dart
// ✅ GOOD: Fresh database for each test
setUp(() {
  db = AppDatabase(NativeDatabase.memory());  // In-memory = isolated
  repo = TodoRepository(db);
  syncService = SyncService(db: db, baseUrl: url);
});

tearDown(() async {
  syncService.dispose();
  await db.close();
});

// ❌ BAD: Shared database between tests
final db = AppDatabase(NativeDatabase.memory());  // Created once, shared
```

### 2. Always Use pumpAndSettle

```dart
// ✅ GOOD: Wait for UI to stabilize
await repo.create(title: 'Test');
await tester.pumpAndSettle();  // Wait for StreamBuilder to rebuild
expect(find.text('Test'), findsOneWidget);

// ❌ BAD: Check immediately
await repo.create(title: 'Test');
expect(find.text('Test'), findsOneWidget);  // May fail!
```

### 3. Use Unique Names

```dart
// ✅ GOOD: Unique per test run
final todo = uniqueName('Task');  // "Task-1703089234567"

// ❌ BAD: Static names conflict with persistent backend
final todo = 'Task';  // Collides with previous test runs
```

### 4. Verify Final State

```dart
// ✅ GOOD: Verify both UI and data
await syncAndVerify(expectedPushed: 2);
expect(find.text(todo1), findsOneWidget);  // UI check
expect(find.text(todo2), findsOneWidget);  // UI check
expect(await syncService.getPendingCount(), 0);  // Data check

// ❌ BAD: Only check UI
expect(find.text(todo1), findsOneWidget);  // UI might be stale
```

### 5. Document Test Phases

```dart
// ✅ GOOD: Clear phase markers
// ╔═══════════════════════════════════════════════════════════════════╗
// ║ PHASE 1: ONLINE                                                    ║
// ╚═══════════════════════════════════════════════════════════════════╝
await createAndSync(title);

// ❌ BAD: No structure
await repo.create(title: title);
await syncService.sync();
await repo.update(todo, title: newTitle);
await syncService.sync();  // Which phase is this?
```

---

## Common Mistakes

### 1. Forgetting pumpAndSettle

```dart
// ❌ WRONG
await repo.create(title: 'Test');
expect(find.text('Test'), findsNothing);  // Fails! UI not updated yet

// ✅ CORRECT
await repo.create(title: 'Test');
await tester.pumpAndSettle();  // Wait for rebuild
expect(find.text('Test'), findsOneWidget);
```

### 2. Not Closing Database

```dart
// ❌ WRONG: Memory leak, test pollution
tearDown(() async {
  syncService.dispose();
  // Missing: await db.close();
});

// ✅ CORRECT
tearDown(() async {
  syncService.dispose();
  await db.close();
});
```

### 3. Using Static Test Data

```dart
// ❌ WRONG: Conflicts with persistent backend
await repo.create(title: 'Buy milk');  // Already exists from last run!

// ✅ CORRECT
await repo.create(title: uniqueName('Buy milk'));  // Unique each run
```

### 4. Assuming Instant Sync

```dart
// ❌ WRONG: Sync is async
await repo.create(title: 'Test');
await syncService.sync();
expect(syncService.status, SyncStatus.idle);  // May still be syncing!

// ✅ CORRECT: Use helper that waits
await syncAndVerify(expectedPushed: 1);
```

### 5. Ignoring Network Recovery Order

```dart
// ❌ WRONG: Testing recovery before creating offline data
await syncService.sync();  // Nothing to sync!
expect(stats.pushed, 0);

// ✅ CORRECT: Create → Queue → Recover
await repo.create(title: 'Offline');  // Create locally
await expectPending(1);               // Verify queued
await syncAndVerify(expectedPushed: 1);  // Recover
```

---

## Troubleshooting

### Tests Won't Start

```bash
# Problem: No devices found
flutter devices

# Solution: Start simulator
open -a Simulator  # macOS
flutter emulators --launch <emulator_id>
```

### Network Recovery Tests Fail

```bash
# Problem: Connection refused
# Solution: Verify backend is running

curl http://localhost:8080/health
# Expected: {"status":"ok"}

# If not working:
cd ../backend
dart_frog dev
```

### Tests Hang on pumpAndSettle

```dart
// Problem: Infinite animation or timer
// Solution: Use pump with timeout

await tester.pump(const Duration(seconds: 2));
await tester.pumpAndSettle(const Duration(seconds: 5));
```

### Flaky Tests

```dart
// Problem: Test sometimes fails
// Cause: Race condition or insufficient pump

// Solution 1: Add pumpAndSettle after operations
await repo.create(title: 'Test');
await tester.pumpAndSettle();  // Always!

// Solution 2: Increase timeout
await tester.pumpAndSettle(const Duration(seconds: 3));
```

### Database Not Clean

```dart
// Problem: Data from previous test
// Solution: In-memory database in setUp

setUp(() {
  db = AppDatabase(NativeDatabase.memory());  // Fresh each test
});
```

### "Timer still pending" Warning

```dart
// Problem: Resource not disposed
// Solution: Dispose in correct order

tearDown(() async {
  syncService.dispose();  // First: may have timers
  await db.close();       // Last: database
});
```

---

## PR Checklist

Before creating a PR, verify:

- [ ] `flutter test integration_test/offline_test.dart` — all pass
- [ ] `flutter test integration_test/network_recovery_test.dart` — all pass (with backend)
- [ ] `flutter analyze` — no errors
- [ ] New tests follow three-phase pattern (ONLINE/OFFLINE/RECOVERY)
- [ ] Using `uniqueName()` for test data
- [ ] `tearDown()` closes all resources (db, syncService)
- [ ] All operations followed by `pumpAndSettle()`
- [ ] Test names are descriptive (VERB: description)

---

## Related Links

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Drift Database](https://drift.simonbinder.eu/)
- [Offline-First Architecture](https://offlinefirst.org/)
- [Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html)

---

*Last updated: December 2025*
