import 'package:offline_first_sync_drift/src/services/conflict_service.dart';
import 'package:test/test.dart';

void main() {
  group('ConflictResolutionResult', () {
    test('creates with resolved true and no data', () {
      const result = ConflictResolutionResult(resolved: true);

      expect(result.resolved, isTrue);
      expect(result.resultData, isNull);
    });

    test('creates with resolved true and data', () {
      const result = ConflictResolutionResult(
        resolved: true,
        resultData: {'id': '123', 'name': 'Test'},
      );

      expect(result.resolved, isTrue);
      expect(result.resultData, isNotNull);
      expect(result.resultData!['id'], '123');
      expect(result.resultData!['name'], 'Test');
    });

    test('creates with resolved false', () {
      const result = ConflictResolutionResult(resolved: false);

      expect(result.resolved, isFalse);
      expect(result.resultData, isNull);
    });

    test('creates with resolved false and data', () {
      const result = ConflictResolutionResult(
        resolved: false,
        resultData: {'error': 'conflict'},
      );

      expect(result.resolved, isFalse);
      expect(result.resultData, isNotNull);
      expect(result.resultData!['error'], 'conflict');
    });

    test('can be const', () {
      const result1 = ConflictResolutionResult(resolved: true);
      const result2 = ConflictResolutionResult(resolved: false);

      expect(result1.resolved, isNot(result2.resolved));
    });

    test('resultData can contain complex objects', () {
      const result = ConflictResolutionResult(
        resolved: true,
        resultData: {
          'id': '123',
          'nested': {'key': 'value'},
          'list': [1, 2, 3],
        },
      );

      expect(result.resultData!['nested'], {'key': 'value'});
      expect(result.resultData!['list'], [1, 2, 3]);
    });
  });
}
