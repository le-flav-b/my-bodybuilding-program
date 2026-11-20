import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'body_weight_providers.g.dart';

/// The bodyweight log, newest first.
@Riverpod(keepAlive: true)
Stream<List<BodyWeight>> bodyWeights(Ref ref) =>
    ref.watch(bodyWeightRepositoryProvider).watchEntries();

/// Set by a tap on the weigh-in reminder: the Profile then opens the
/// log-weight dialog, once.
@Riverpod(keepAlive: true)
class WeighInRequest extends _$WeighInRequest {
  @override
  bool build() => false;

  void request() => state = true;

  /// True once per request: the caller opens the dialog.
  bool take() {
    if (!state) return false;
    state = false;
    return true;
  }
}
