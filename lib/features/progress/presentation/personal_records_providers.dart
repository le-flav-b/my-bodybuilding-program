import 'package:my_bodybuilding_program/features/progress/data/personal_records_repository.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'personal_records_providers.g.dart';

/// Every personal record, newest first.
@Riverpod(keepAlive: true)
Stream<List<PersonalRecord>> personalRecords(Ref ref) =>
    ref.watch(personalRecordsRepositoryProvider).watchRecords();

/// The personal records of one exercise, newest first.
@riverpod
List<PersonalRecord> exercisePersonalRecords(Ref ref, String exerciseId) => [
  for (final r
      in ref.watch(personalRecordsProvider).value ?? const <PersonalRecord>[])
    if (r.exerciseId == exerciseId) r,
];
