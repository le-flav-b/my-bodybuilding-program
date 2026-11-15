/// The rotation rule: the program is a loop of sessions and a pointer to the
/// next one, which follows what was actually done.
///
/// All functions take the session ids in loop order.
abstract final class Rotation {
  /// The session the pointer designates: [pointer] when it is still in the
  /// loop, otherwise the first session; null when the program is empty.
  static String? resolve(List<String> sessionIds, String? pointer) {
    if (sessionIds.isEmpty) return null;
    return sessionIds.contains(pointer) ? pointer : sessionIds.first;
  }

  /// The session after [sessionId], wrapping around. Null when the program
  /// is empty; the first session when [sessionId] is not in the loop.
  static String? following(List<String> sessionIds, String? sessionId) {
    if (sessionIds.isEmpty) return null;
    final index = sessionId == null ? -1 : sessionIds.indexOf(sessionId);
    if (index < 0) return sessionIds.first;
    return sessionIds[(index + 1) % sessionIds.length];
  }

  /// Pointer after finishing a workout.
  ///
  /// Finishing a workout started from session N points to the session after
  /// N, even if N was not the suggested one. An empty workout
  /// ([finishedSessionId] null) or one whose session no longer exists leaves
  /// the pointer where it is.
  static String? afterWorkout(
    List<String> sessionIds,
    String? pointer,
    String? finishedSessionId,
  ) {
    if (finishedSessionId == null || !sessionIds.contains(finishedSessionId)) {
      return resolve(sessionIds, pointer);
    }
    return following(sessionIds, finishedSessionId);
  }

  /// Pointer after "Skip": the session following the current one.
  static String? afterSkip(List<String> sessionIds, String? pointer) =>
      following(sessionIds, resolve(sessionIds, pointer));

  /// Pointer after deleting [deletedSessionId]. [sessionIds] is the loop
  /// before the deletion. If the deleted session was next, the one after it
  /// becomes next.
  static String? afterDelete(
    List<String> sessionIds,
    String? pointer,
    String deletedSessionId,
  ) {
    final remaining = [
      for (final id in sessionIds)
        if (id != deletedSessionId) id,
    ];
    if (remaining.isEmpty) return null;
    final current = resolve(sessionIds, pointer);
    if (current != deletedSessionId) return current;
    final next = following(sessionIds, deletedSessionId);
    return next == deletedSessionId ? remaining.first : next;
  }

  /// 1-based place of the pointed session in the loop ("2 of 3"), or null.
  static int? placeOf(List<String> sessionIds, String? pointer) {
    final current = resolve(sessionIds, pointer);
    return current == null ? null : sessionIds.indexOf(current) + 1;
  }
}
