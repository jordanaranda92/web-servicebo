import 'dart:ui';

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
abstract class OrdersPresenceRepository {
  /// Sets up disconnect cleanup for the user.
  Future<void> setupDisconnectCleanup(String userId);

  /// Updates the current user's cursor position.
  Future<void> updateMyCursor({
    required String userId,
    String? productId,
    String? clientId,
    required String color,
    required String userName,
  });

  /// Removes stale locks.
  Future<void> cleanExpiredLocks();

  /// Stream of lock changes.
  Stream<CellLockChange> onLockChanged();

  /// Stream of cursor changes.
  Stream<RemoteCursorChange> onCursorChanged(
    Color Function(String hex) colorParser,
  );

  /// Attempts to acquire a lock. Returns `true` if acquired.
  Future<bool> acquireLock(String cellKey, String userId);

  /// Releases a lock.
  Future<void> releaseLock(String cellKey);

  /// Returns all current locks as domain entities.
  Future<Map<String, CellLock>> getAllLocks();

  /// Returns all current cursors as domain entities.
  Future<Map<String, RemoteCursor>> getAllCursors(
    Color Function(String hex) colorParser,
  );

  /// Removes the user's cursor.
  Future<void> removeMyCursor(String userId);

  /// Releases subscriptions and resources.
  void dispose();
}
