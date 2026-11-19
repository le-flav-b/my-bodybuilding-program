import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'body_weight_providers.g.dart';

/// The bodyweight log, newest first.
@Riverpod(keepAlive: true)
Stream<List<BodyWeight>> bodyWeights(Ref ref) =>
    ref.watch(bodyWeightRepositoryProvider).watchEntries();
