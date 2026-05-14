import '../../domain/entities/cell_lock.dart';
import '../../domain/entities/remote_cursor.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import '../datasources/remote/orders_rtdb_data_source.dart';

class OrdersPresenceRepositoryImpl implements OrdersPresenceRepository {
  OrdersPresenceRepositoryImpl(this._dataSource);

  final OrdersRtdbDataSource _dataSource;

  @override
  Future<void> setupDisconnectCleanup(String userId) =>
      _dataSource.setupDisconnectCleanup(userId);

  @override
  Future<void> updateMyCursor({
    required String userId,
    String? productId,
    String? clientId,
    required String userName,
  }) => _dataSource.updateMyCursor(userId, productId, clientId, userName);

  @override
  Future<void> cleanExpiredLocks() => _dataSource.cleanExpiredLocks();

  @override
  Stream<CellLockChange> onLockChanged() {
    return _dataSource.onLockChanged().map((update) {
      CellLock? lock;
      if (update.lock case final info?) {
        lock = CellLock(
          cellKey: update.key,
          user: info.user,
          timestamp: DateTime.fromMillisecondsSinceEpoch(info.timestamp * 1000),
        );
      }
      return CellLockChange(
        key: update.key,
        lock: lock,
        removed: update.removed,
      );
    });
  }

  @override
  Stream<RemoteCursorChange> onCursorChanged() {
    return _dataSource.onCursorChanged().map((update) {
      RemoteCursor? cursor;
      if (update.cursor case final info?) {
        cursor = RemoteCursor(
          userId: update.userId,
          userName: info.userName ?? update.userId,
          productId: info.productId,
          clientId: info.clientId,
        );
      }
      return RemoteCursorChange(
        userId: update.userId,
        cursor: cursor,
        removed: update.removed,
      );
    });
  }

  @override
  Future<bool> acquireLock(String cellKey, String userId) =>
      _dataSource.acquireLock(cellKey, userId);

  @override
  Future<void> releaseLock(String cellKey) => _dataSource.releaseLock(cellKey);

  @override
  Future<Map<String, CellLock>> getAllLocks() async {
    final locks = await _dataSource.getAllLocks();
    return locks.map(
      (key, info) => MapEntry(
        key,
        CellLock(
          cellKey: key,
          user: info.user,
          timestamp: DateTime.fromMillisecondsSinceEpoch(info.timestamp * 1000),
        ),
      ),
    );
  }

  @override
  Future<Map<String, RemoteCursor>> getAllCursors() async {
    final cursors = await _dataSource.getAllCursors();
    return cursors.map(
      (key, info) => MapEntry(
        key,
        RemoteCursor(
          userId: key,
          userName: info.userName ?? key,
          productId: info.productId,
          clientId: info.clientId,
        ),
      ),
    );
  }

  @override
  Future<void> removeMyCursor(String userId) =>
      _dataSource.removeMyCursor(userId);

  @override
  void dispose() => _dataSource.dispose();
}
