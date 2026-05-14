/// Provides the current authenticated user's identity for action logging.
abstract class CurrentUserProvider {
  /// Returns (uid, userName) or `null` if not authenticated.
  ({String uid, String userName})? get currentUser;

  /// Resolves the userName from the backend (e.g. Firestore `users` collection).
  Future<void> resolve();
}
