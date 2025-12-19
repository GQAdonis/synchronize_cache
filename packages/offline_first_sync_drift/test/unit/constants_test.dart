import 'package:offline_first_sync_drift/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('OpType', () {
    test('upsert has correct value', () {
      expect(OpType.upsert, equals('upsert'));
    });

    test('delete has correct value', () {
      expect(OpType.delete, equals('delete'));
    });
  });

  group('SyncFields', () {
    group('ID fields', () {
      test('id has correct value', () {
        expect(SyncFields.id, equals('id'));
      });

      test('idUpper has correct value', () {
        expect(SyncFields.idUpper, equals('ID'));
      });

      test('uuid has correct value', () {
        expect(SyncFields.uuid, equals('uuid'));
      });

      test('idFields contains all ID fields', () {
        expect(SyncFields.idFields, hasLength(3));
        expect(SyncFields.idFields, contains('id'));
        expect(SyncFields.idFields, contains('ID'));
        expect(SyncFields.idFields, contains('uuid'));
      });
    });

    group('Timestamp fields (camelCase)', () {
      test('updatedAt has correct value', () {
        expect(SyncFields.updatedAt, equals('updatedAt'));
      });

      test('createdAt has correct value', () {
        expect(SyncFields.createdAt, equals('createdAt'));
      });

      test('deletedAt has correct value', () {
        expect(SyncFields.deletedAt, equals('deletedAt'));
      });
    });

    group('Timestamp fields (snake_case)', () {
      test('updatedAtSnake has correct value', () {
        expect(SyncFields.updatedAtSnake, equals('updated_at'));
      });

      test('createdAtSnake has correct value', () {
        expect(SyncFields.createdAtSnake, equals('created_at'));
      });

      test('deletedAtSnake has correct value', () {
        expect(SyncFields.deletedAtSnake, equals('deleted_at'));
      });
    });

    group('Field lists', () {
      test('updatedAtFields contains both formats', () {
        expect(SyncFields.updatedAtFields, hasLength(2));
        expect(SyncFields.updatedAtFields, contains('updatedAt'));
        expect(SyncFields.updatedAtFields, contains('updated_at'));
      });

      test('deletedAtFields contains both formats', () {
        expect(SyncFields.deletedAtFields, hasLength(2));
        expect(SyncFields.deletedAtFields, contains('deletedAt'));
        expect(SyncFields.deletedAtFields, contains('deleted_at'));
      });
    });
  });

  group('TableColumns', () {
    test('opId has correct value', () {
      expect(TableColumns.opId, equals('op_id'));
    });

    test('kind has correct value', () {
      expect(TableColumns.kind, equals('kind'));
    });

    test('entityId has correct value', () {
      expect(TableColumns.entityId, equals('entity_id'));
    });

    test('op has correct value', () {
      expect(TableColumns.op, equals('op'));
    });

    test('payload has correct value', () {
      expect(TableColumns.payload, equals('payload'));
    });

    test('ts has correct value', () {
      expect(TableColumns.ts, equals('ts'));
    });

    test('tryCount has correct value', () {
      expect(TableColumns.tryCount, equals('try_count'));
    });

    test('baseUpdatedAt has correct value', () {
      expect(TableColumns.baseUpdatedAt, equals('base_updated_at'));
    });

    test('changedFields has correct value', () {
      expect(TableColumns.changedFields, equals('changed_fields'));
    });

    test('lastId has correct value', () {
      expect(TableColumns.lastId, equals('last_id'));
    });
  });

  group('TableNames', () {
    test('syncOutbox has correct value', () {
      expect(TableNames.syncOutbox, equals('sync_outbox'));
    });

    test('syncCursors has correct value', () {
      expect(TableNames.syncCursors, equals('sync_cursors'));
    });
  });

  group('CursorKinds', () {
    test('fullResync has correct value', () {
      expect(CursorKinds.fullResync, equals('__full_resync__'));
    });
  });
}
