import '../entities/cell_lock.dart';
import '../entities/remote_cursor.dart';

/// Domain event representing a lock change.
class CellLockChange {
  final String key;
  final CellLock? lock;
  final bool removed;

  const CellLockChange({required this.key, this.lock, this.removed = false});
}

/// Domain event representing a cursor change.
class RemoteCursorChange {
  final String userId;
  final RemoteCursor? cursor;
  final bool removed;

  const RemoteCursorChange({
    required this.userId,
    this.cursor,
    this.removed = false,
  });
}

/// Repository contract for real-time collaboration presence.
///
/// All operations are scoped to a [dateKey] (format `YYYY-MM-DD`) so that
/// cursors and locks are isolated per day.
abstract class OrdersPresenceRepository {
  /// Sets up disconnect cleanup for the user.
  Future<void> setupDisconnectCleanup(String userId, {required String dateKey});

  /// Updates the current user's cursor position.
  Future<void> updateMyCursor({
    required String userId,
    String? productId,
    String? clientId,
    required String userName,
    required String dateKey,
  });

  /// Removes stale locks.
  Future<void> cleanExpiredLocks({required String dateKey});

  /// Stream of lock changes.
  Stream<CellLockChange> onLockChanged({required String dateKey});

  /// Stream of cursor changes.
  Stream<RemoteCursorChange> onCursorChanged({required String dateKey});

  /// Attempts to acquire a lock. Returns `true` if acquired.
  Future<bool> acquireLock(
    String cellKey,
    String userId, {
    required String dateKey,
  });

  /// Releases a lock.
  Future<void> releaseLock(String cellKey, {required String dateKey});

  /// Returns all current locks as domain entities.
  Future<Map<String, CellLock>> getAllLocks({required String dateKey});

  /// Returns all current cursors as domain entities.
  Future<Map<String, RemoteCursor>> getAllCursors({required String dateKey});

  /// Removes the user's cursor.
  Future<void> removeMyCursor(String userId, {required String dateKey});

  /// Releases subscriptions and resources.
  void dispose();
}
