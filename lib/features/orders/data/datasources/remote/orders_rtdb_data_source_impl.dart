import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../../../../core/log/app_logger.dart';
import '../../dto/cursor_info.dart';
import '../../dto/lock_info.dart';
import 'orders_rtdb_data_source.dart';

class OrdersRtdbDataSourceImpl implements OrdersRtdbDataSource {
  OrdersRtdbDataSourceImpl(this._db, this._logger);

  final FirebaseDatabase _db;
  final AppLogger _logger;

  DatabaseReference _dateRef(String dateKey) => _db.ref('orders/$dateKey');
  DatabaseReference _locksRef(String dateKey) =>
      _dateRef(dateKey).child('locks');
  DatabaseReference _cursorsRef(String dateKey) =>
      _dateRef(dateKey).child('cursors');

  // ── Locks ───────────────────────────────────────────────────────

  @override
  Future<bool> acquireLock(
    String cellKey,
    String userId, {
    required String dateKey,
  }) async {
    final ref = _locksRef(dateKey).child(cellKey);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final result = await ref.runTransaction((currentValue) {
      if (currentValue == null) {
        // No lock — acquire it
        return Transaction.success({'user': userId, 'ts': now});
      }

      final map = Map<String, dynamic>.from(currentValue as Map);
      final lockUser = map['user'] as String?;
      final lockTs = map['ts'] as int? ?? 0;

      // My own lock — refresh timestamp
      if (lockUser == userId) {
        return Transaction.success({'user': userId, 'ts': now});
      }

      // Someone else's lock — check if expired (>60s)
      if (now - lockTs > 60) {
        return Transaction.success({'user': userId, 'ts': now});
      }

      // Active lock from another user — abort
      return Transaction.abort();
    });

    return result.committed;
  }

  @override
  Future<void> releaseLock(String cellKey, {required String dateKey}) async {
    await _locksRef(dateKey).child(cellKey).remove();
  }

  @override
  Stream<LockUpdate> onLockChanged({required String dateKey}) {
    final controller = StreamController<LockUpdate>.broadcast();
    final locksRef = _locksRef(dateKey);

    final addSub = locksRef.onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        controller.add(
          LockUpdate(
            key: event.snapshot.key!,
            lock: LockInfo.fromMap(
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
            ),
          ),
        );
      }
    });

    final changeSub = locksRef.onChildChanged.listen((event) {
      if (event.snapshot.value != null) {
        controller.add(
          LockUpdate(
            key: event.snapshot.key!,
            lock: LockInfo.fromMap(
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
            ),
          ),
        );
      }
    });

    final removeSub = locksRef.onChildRemoved.listen((event) {
      controller.add(LockUpdate(key: event.snapshot.key!, removed: true));
    });

    controller.onCancel = () {
      addSub.cancel();
      changeSub.cancel();
      removeSub.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<CursorUpdate> onCursorChanged({required String dateKey}) {
    final controller = StreamController<CursorUpdate>.broadcast();
    final cursorsRef = _cursorsRef(dateKey);

    final addSub = cursorsRef.onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        controller.add(
          CursorUpdate(
            userId: event.snapshot.key!,
            cursor: CursorInfo.fromMap(
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
            ),
          ),
        );
      }
    });

    final changeSub = cursorsRef.onChildChanged.listen((event) {
      if (event.snapshot.value != null) {
        controller.add(
          CursorUpdate(
            userId: event.snapshot.key!,
            cursor: CursorInfo.fromMap(
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
            ),
          ),
        );
      }
    });

    final removeSub = cursorsRef.onChildRemoved.listen((event) {
      controller.add(CursorUpdate(userId: event.snapshot.key!, removed: true));
    });

    controller.onCancel = () {
      addSub.cancel();
      changeSub.cancel();
      removeSub.cancel();
    };

    return controller.stream;
  }

  // ── Cursors ─────────────────────────────────────────────────────

  @override
  Future<void> updateMyCursor(
    String userId,
    String? productId,
    String? clientId,
    String userName, {
    required String dateKey,
  }) async {
    await _cursorsRef(dateKey).child(userId).set({
      // ignore: use_null_aware_elements
      if (productId != null) 'pid': productId,
      // ignore: use_null_aware_elements
      if (clientId != null) 'cid': clientId,
      'name': userName,
    });
  }

  @override
  Future<void> setupDisconnectCleanup(
    String userId, {
    required String dateKey,
  }) async {
    try {
      await _cursorsRef(dateKey).child(userId).onDisconnect().remove();
    } on Exception catch (e) {
      _logger.warning('onDisconnect not supported, using TTL fallback', e);
    }
  }

  @override
  Future<void> removeMyCursor(String userId, {required String dateKey}) async {
    await _cursorsRef(dateKey).child(userId).remove();
  }

  // ── Expired lock cleanup ────────────────────────────────────────

  @override
  Future<void> cleanExpiredLocks({required String dateKey}) async {
    final snapshot = await _locksRef(dateKey).get();
    if (snapshot.value == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final locks = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in locks.entries) {
      final lockMap = Map<String, dynamic>.from(entry.value as Map);
      final ts = lockMap['ts'] as int? ?? 0;
      if (now - ts > 60) {
        await _locksRef(dateKey).child(entry.key).remove();
      }
    }
  }

  // ── Snapshots ───────────────────────────────────────────────────

  @override
  Future<Map<String, LockInfo>> getAllLocks({required String dateKey}) async {
    final snapshot = await _locksRef(dateKey).get();
    if (snapshot.value == null) return {};

    final map = Map<String, dynamic>.from(snapshot.value as Map);
    return map.map(
      (key, value) => MapEntry(
        key,
        LockInfo.fromMap(Map<dynamic, dynamic>.from(value as Map)),
      ),
    );
  }

  @override
  Future<Map<String, CursorInfo>> getAllCursors({
    required String dateKey,
  }) async {
    final snapshot = await _cursorsRef(dateKey).get();
    if (snapshot.value == null) return {};

    final map = Map<String, dynamic>.from(snapshot.value as Map);
    return map.map(
      (key, value) => MapEntry(
        key,
        CursorInfo.fromMap(Map<dynamic, dynamic>.from(value as Map)),
      ),
    );
  }

  @override
  void dispose() {
    // Streams are cleaned up via controller.onCancel when listeners cancel.
  }
}
