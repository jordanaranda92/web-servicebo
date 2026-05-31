import '../../domain/entities/cell_lock.dart';
import '../../domain/entities/remote_cursor.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import '../datasources/remote/orders_rtdb_data_source.dart';

class OrdersPresenceRepositoryImpl implements OrdersPresenceRepository {
  OrdersPresenceRepositoryImpl(this._dataSource);

  final OrdersRtdbDataSource _dataSource;

  @override
  Future<void> setupDisconnectCleanup(
    String userId, {
    required String dateKey,
  }) => _dataSource.setupDisconnectCleanup(userId, dateKey: dateKey);

  @override
  Future<void> updateMyCursor({
    required String userId,
    String? productId,
    String? clientId,
    required String userName,
    required String dateKey,
  }) => _dataSource.updateMyCursor(
    userId,
    productId,
    clientId,
    userName,
    dateKey: dateKey,
  );

  @override
  Future<void> cleanExpiredLocks({required String dateKey}) =>
      _dataSource.cleanExpiredLocks(dateKey: dateKey);

  @override
  Stream<CellLockChange> onLockChanged({required String dateKey}) {
    return _dataSource.onLockChanged(dateKey: dateKey).map((update) {
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
  Stream<RemoteCursorChange> onCursorChanged({required String dateKey}) {
    return _dataSource.onCursorChanged(dateKey: dateKey).map((update) {
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
  Future<bool> acquireLock(
    String cellKey,
    String userId, {
    required String dateKey,
  }) => _dataSource.acquireLock(cellKey, userId, dateKey: dateKey);

  @override
  Future<void> releaseLock(String cellKey, {required String dateKey}) =>
      _dataSource.releaseLock(cellKey, dateKey: dateKey);

  @override
  Future<Map<String, CellLock>> getAllLocks({required String dateKey}) async {
    final locks = await _dataSource.getAllLocks(dateKey: dateKey);
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
  Future<Map<String, RemoteCursor>> getAllCursors({
    required String dateKey,
  }) async {
    final cursors = await _dataSource.getAllCursors(dateKey: dateKey);
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
  Future<void> removeMyCursor(String userId, {required String dateKey}) =>
      _dataSource.removeMyCursor(userId, dateKey: dateKey);

  @override
  void dispose() => _dataSource.dispose();
}
