/// Contract for ABA file sequence number persistence.
abstract interface class IAbaSequenceRepository {
  /// Atomically increments and returns the daily ABA sequence number for [entityId].
  ///
  /// The sequence resets to 1 each calendar day. The first call on a given day
  /// returns 1, the second returns 2, and so on.
  Future<int> nextSequence(String entityId);
}
