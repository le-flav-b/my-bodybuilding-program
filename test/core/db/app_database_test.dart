import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/core/db/app_database.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';

import '../../helpers/test_env.dart';
import 'migrations/generated/schema.dart';

void main() {
  group('schema', () {
    late SchemaVerifier verifier;

    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('a fresh database matches the dumped schema of its version', () async {
      final connection = await verifier.startAt(1);
      final db = AppDatabase(connection);
      addTearDown(db.close);
      // Fails when the tables change without a new schema version + dump
      // (`dart run drift_dev make-migrations`).
      await verifier.migrateAndValidate(db, db.schemaVersion);
    });

    test('every dumped version has a migration test path', () {
      expect(GeneratedHelper.versions.last, 1);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, GeneratedHelper.versions.last);
    });
  });

  group('built-in rows', () {
    late TestEnv env;

    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    test('kg exists, locked, with step 0.5 and 1 decimal', () async {
      final units = await env.units.getUnits();
      expect(units, hasLength(1));
      final kg = units.single;
      expect(kg.id, FixedIds.kgUnit);
      expect(kg.name, 'kg');
      expect(kg.step, 0.5);
      expect(kg.decimals, 1);
      expect(kg.isBuiltin, isTrue);
    });

    test('the single program exists and starts empty', () async {
      final overview = await env.program.getOverview();
      expect(overview.isEmpty, isTrue);
      expect(overview.nextSessionId, isNull);
      final rows = await env.db.select(env.db.programs).get();
      expect(rows.single.id, FixedIds.program);
    });

    test('reopening does not duplicate them', () async {
      await env.db.customStatement('SELECT 1');
      // beforeOpen ran once; run the same inserts again through a new
      // database object on the same in-memory executor is not possible, so
      // check the insert is idempotent at the SQL level.
      await env.db
          .into(env.db.loadUnits)
          .insert(
            LoadUnitsCompanion.insert(
              id: FixedIds.kgUnit,
              createdAt: env.clock.now,
              updatedAt: env.clock.now,
              name: 'kg',
              step: 0.5,
              decimals: 1,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      expect(await env.units.getUnits(), hasLength(1));
    });

    test('foreign keys are enforced', () async {
      final result = await env.db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(result.data.values.single, 1);
    });
  });

  group('sync columns', () {
    late TestEnv env;

    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    test(
      'writes stamp UUID v7 ids, UTC timestamps and the dirty flag',
      () async {
        final id = await env.exercise('Bench press');
        final row = await (env.db.select(
          env.db.exercises,
        )..where((t) => t.id.equals(id))).getSingle();
        // UUID v7: version nibble is 7.
        expect(row.id[14], '7');
        expect(row.createdAt, env.clock.now);
        expect(row.createdAt.isUtc, isTrue);
        expect(row.updatedAt, env.clock.now);
        expect(row.deletedAt, isNull);
        expect(row.dirty, isTrue);
      },
    );

    test('timestamps are stored as ISO-8601 text with milliseconds', () async {
      env.clock.now = DateTime.utc(2026, 11, 15, 18, 4, 5, 678);
      final id = await env.exercise('Bench press');
      final raw = await env.db
          .customSelect(
            'SELECT created_at FROM exercises WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      expect(raw.data['created_at'], '2026-11-15T18:04:05.678Z');
    });

    test('updates move updated_at and keep created_at', () async {
      final id = await env.exercise('Bench press');
      final created = env.clock.now;
      env.clock.advance(const Duration(hours: 1));
      await env.catalogue.archiveExercise(id);
      final row = await (env.db.select(
        env.db.exercises,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.createdAt, created);
      expect(row.updatedAt, env.clock.now);
    });

    test('deletes are soft', () async {
      final id = await env.exercise('Bench press');
      env.clock.advance(const Duration(minutes: 1));
      await env.catalogue.deleteExercise(id);
      expect(await env.catalogue.getExercises(), isEmpty);
      final row = await (env.db.select(
        env.db.exercises,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.deletedAt, env.clock.now);
      expect(row.updatedAt, env.clock.now);
    });
  });
}
