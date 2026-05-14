import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/auth/current_user_provider.dart';
import '../datasources/auth_remote_data_source.dart';

class FirebaseCurrentUserProvider implements CurrentUserProvider {
  FirebaseCurrentUserProvider(this._firebaseAuth, this._authDataSource);

  final FirebaseAuth _firebaseAuth;
  final AuthRemoteDataSource _authDataSource;

  ({String uid, String userName})? _cached;
  bool _resolved = false;

  @override
  ({String uid, String userName})? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    // Return cached value if already resolved from Firestore.
    if (_cached != null && _cached!.uid == user.uid) return _cached!;
    // Trigger async resolution (best-effort, fire-and-forget).
    if (!_resolved) {
      _resolved = true;
      _resolveUserName(user.uid);
    }
    // Fallback until resolve completes.
    return (uid: user.uid, userName: user.displayName ?? user.uid);
  }

  /// Resolves the userName from Firestore `users` collection.
  /// Called lazily on first access and also callable at startup.
  @override
  Future<void> resolve() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await _resolveUserName(user.uid);
  }

  Future<void> _resolveUserName(String uid) async {
    try {
      final name = await _authDataSource.getUserName(uid);
      _cached = (uid: uid, userName: name ?? uid);
    } on Exception {
      // Best-effort: keep UID as fallback.
    }
  }
}
