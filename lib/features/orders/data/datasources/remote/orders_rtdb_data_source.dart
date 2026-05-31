import '../../dto/cursor_info.dart';
import '../../dto/lock_info.dart';

/// Datasource for real-time collaboration via Firebase Realtime Database.
/// Used exclusively for presence (cursors and locks).
///
/// All operations are scoped to a [dateKey] (format `YYYY-MM-DD`) so that
/// presence data is isolated per day.
abstract class OrdersRtdbDataSource {
  /// Attempts to acquire a lock on [cellKey] for [userId].
  /// Returns `true` if the lock was acquired, `false` if another user holds it.
  Future<bool> acquireLock(
    String cellKey,
    String userId, {
    required String dateKey,
  });

  /// Releases a lock on [cellKey].
  Future<void> releaseLock(String cellKey, {required String dateKey});

  /// Stream of lock changes (add/update/remove).
  Stream<LockUpdate> onLockChanged({required String dateKey});

  /// Stream of cursor changes (add/update/remove).
  Stream<CursorUpdate> onCursorChanged({required String dateKey});

  /// Registers or updates the current user's cursor position.
  Future<void> updateMyCursor(
    String userId,
    String? productId,
    String? clientId,
    String userName, {
    required String dateKey,
  });

  /// Sets up `onDisconnect` to clean the user's cursor when disconnected.
  Future<void> setupDisconnectCleanup(String userId, {required String dateKey});

  /// Removes locks older than 60 seconds.
  Future<void> cleanExpiredLocks({required String dateKey});

  /// Returns a snapshot of all current locks.
  Future<Map<String, LockInfo>> getAllLocks({required String dateKey});

  /// Returns a snapshot of all current cursors.
  Future<Map<String, CursorInfo>> getAllCursors({required String dateKey});

  /// Removes the user's cursor.
  Future<void> removeMyCursor(String userId, {required String dateKey});

  /// Releases all resources.
  void dispose();
}
