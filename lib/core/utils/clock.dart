import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Returns the current instant. Injected so rules and repositories can be
/// tested with a fixed time.
typedef Clock = DateTime Function();

/// The real clock, in UTC.
DateTime utcNow() => DateTime.now().toUtc();

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => utcNow;
