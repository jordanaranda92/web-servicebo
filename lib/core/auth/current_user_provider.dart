/// Provides the current authenticated user's identity for action logging.
abstract class CurrentUserProvider {
  /// Returns (uid, userName, color) or `null` if not authenticated.
  ({String uid, String userName, String? color})? get currentUser;

  /// Resolves the userName and color from the backend
  /// (e.g. Firestore `users` collection).
  Future<void> resolve();
}
