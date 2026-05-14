import '../../dto/cursor_info.dart';
import '../../dto/lock_info.dart';

/// Datasource for real-time collaboration via Firebase Realtime Database.
/// Used exclusively for presence (cursors and locks).
abstract class OrdersRtdbDataSource {
  /// Reads the current date stored in the `today` node.
  Future<String?> getTodayDate();

  /// Atomically resets the `today` node for a new [date].
  Future<void> resetToday(String date);

  /// Attempts to acquire a lock on [cellKey] for [userId].
  /// Returns `true` if the lock was acquired, `false` if another user holds it.
  Future<bool> acquireLock(String cellKey, String userId);

  /// Releases a lock on [cellKey].
  Future<void> releaseLock(String cellKey);

  /// Stream of lock changes (add/update/remove).
  Stream<LockUpdate> onLockChanged();

  /// Stream of cursor changes (add/update/remove).
  Stream<CursorUpdate> onCursorChanged();

  /// Registers or updates the current user's cursor position.
  Future<void> updateMyCursor(
    String userId,
    String? productId,
    String? clientId,
    String userName,
  );

  /// Sets up `onDisconnect` to clean the user's cursor when disconnected.
  Future<void> setupDisconnectCleanup(String userId);

  /// Removes locks older than 60 seconds.
  Future<void> cleanExpiredLocks();

  /// Returns a snapshot of all current locks.
  Future<Map<String, LockInfo>> getAllLocks();

  /// Returns a snapshot of all current cursors.
  Future<Map<String, CursorInfo>> getAllCursors();

  /// Removes the user's cursor.
  Future<void> removeMyCursor(String userId);

  /// Releases all resources.
  void dispose();
}
