import 'package:offline_first_sync_drift/src/services/push_service.dart';
import 'package:test/test.dart';

void main() {
  group('PushStats', () {
    test('creates with default values', () {
      const stats = PushStats();

      expect(stats.pushed, 0);
      expect(stats.conflicts, 0);
      expect(stats.conflictsResolved, 0);
      expect(stats.errors, 0);
    });

    test('creates with custom values', () {
      const stats = PushStats(
        pushed: 10,
        conflicts: 2,
        conflictsResolved: 1,
        errors: 3,
      );

      expect(stats.pushed, 10);
      expect(stats.conflicts, 2);
      expect(stats.conflictsResolved, 1);
      expect(stats.errors, 3);
    });

    test('copyWith updates pushed', () {
      const stats = PushStats(pushed: 5);
      final updated = stats.copyWith(pushed: 10);

      expect(updated.pushed, 10);
      expect(updated.conflicts, 0);
      expect(updated.conflictsResolved, 0);
      expect(updated.errors, 0);
    });

    test('copyWith updates conflicts', () {
      const stats = PushStats(conflicts: 3);
      final updated = stats.copyWith(conflicts: 5);

      expect(updated.pushed, 0);
      expect(updated.conflicts, 5);
    });

    test('copyWith updates conflictsResolved', () {
      const stats = PushStats(conflictsResolved: 2);
      final updated = stats.copyWith(conflictsResolved: 4);

      expect(updated.conflictsResolved, 4);
    });

    test('copyWith updates errors', () {
      const stats = PushStats(errors: 1);
      final updated = stats.copyWith(errors: 3);

      expect(updated.errors, 3);
    });

    test('copyWith preserves unchanged values', () {
      const stats = PushStats(
        pushed: 10,
        conflicts: 2,
        conflictsResolved: 1,
        errors: 3,
      );
      final updated = stats.copyWith(pushed: 15);

      expect(updated.pushed, 15);
      expect(updated.conflicts, 2);
      expect(updated.conflictsResolved, 1);
      expect(updated.errors, 3);
    });

    test('copyWith with no arguments returns same values', () {
      const stats = PushStats(
        pushed: 10,
        conflicts: 2,
        conflictsResolved: 1,
        errors: 3,
      );
      final updated = stats.copyWith();

      expect(updated.pushed, stats.pushed);
      expect(updated.conflicts, stats.conflicts);
      expect(updated.conflictsResolved, stats.conflictsResolved);
      expect(updated.errors, stats.errors);
    });

    test('can be const', () {
      const stats = PushStats(
        pushed: 10,
        conflicts: 2,
        conflictsResolved: 1,
        errors: 3,
      );

      expect(stats, isNotNull);
    });
  });
}
