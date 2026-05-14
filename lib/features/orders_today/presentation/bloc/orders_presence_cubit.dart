import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cell_lock.dart';
import '../../domain/entities/remote_cursor.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import 'orders_presence_state.dart';

class OrdersPresenceCubit extends Cubit<OrdersPresenceState> {
  OrdersPresenceCubit({
    required OrdersPresenceRepository repository,
    required this.userId,
    required this.userName,
  }) : _repository = repository,
       myColor = _computeColor(userId),
       super(const OrdersPresenceState());

  final OrdersPresenceRepository _repository;
  final String userId;
  final String userName;

  StreamSubscription<CellLockChange>? _lockSub;
  StreamSubscription<RemoteCursorChange>? _cursorSub;

  /// Color assigned to this user, derived from userId hash.
  final String myColor;

  static const _userColorPalette = [
    '#FF5722',
    '#E91E63',
    '#9C27B0',
    '#673AB7',
    '#3F51B5',
    '#2196F3',
    '#009688',
    '#4CAF50',
    '#FF9800',
    '#795548',
    '#607D8B',
    '#F44336',
  ];

  static String _computeColor(String userId) {
    return _userColorPalette[userId.hashCode.abs() % _userColorPalette.length];
  }

  /// Initialize presence: register cursor, subscribe to changes.
  Future<void> init() async {
    await _repository.setupDisconnectCleanup(userId);
    await _repository.updateMyCursor(
      userId: userId,
      productId: null,
      clientId: null,
      color: myColor,
      userName: userName,
    );
    await _repository.cleanExpiredLocks();

    _lockSub = _repository.onLockChanged().listen(_onLockUpdate);
    _cursorSub = _repository
        .onCursorChanged(_parseColor)
        .listen(_onCursorUpdate);

    // Load initial snapshots
    final lockEntities = await _repository.getAllLocks();
    final allCursors = await _repository.getAllCursors(_parseColor);

    // Remove own cursor from remote list
    final cursorEntities = Map<String, RemoteCursor>.from(allCursors)
      ..remove(userId);

    if (isClosed) return;
    emit(
      OrdersPresenceState(
        locks: lockEntities,
        cursors: cursorEntities,
        connectedUsers: allCursors.length,
      ),
    );
  }

  void _onLockUpdate(CellLockChange change) {
    if (isClosed) return;
    final newLocks = Map<String, CellLock>.from(state.locks);

    if (change.removed) {
      newLocks.remove(change.key);
    } else if (change.lock case final lock?) {
      newLocks[change.key] = lock;
    }

    emit(state.copyWith(locks: newLocks));
  }

  void _onCursorUpdate(RemoteCursorChange change) {
    if (isClosed) return;
    final newCursors = Map<String, RemoteCursor>.from(state.cursors);
    var count = state.connectedUsers;

    if (change.removed) {
      newCursors.remove(change.userId);
      count = (count - 1).clamp(0, 999);
    } else if (change.cursor case final cursor?) {
      if (change.userId == userId) {
        // Don't add own cursor to remote list, but count it
        count = newCursors.length + 1;
      } else {
        newCursors[change.userId] = cursor;
        count = newCursors.length + 1; // +1 for self
      }
    }

    emit(state.copyWith(cursors: newCursors, connectedUsers: count));
  }

  /// Attempt to acquire a lock on [cellKey]. Returns `true` if acquired.
  Future<bool> acquireLock(String cellKey) async {
    return _repository.acquireLock(cellKey, userId);
  }

  /// Release the lock on [cellKey].
  Future<void> releaseLock(String cellKey) async {
    await _repository.releaseLock(cellKey);
  }

  /// Update the current user's cursor position.
  Future<void> updateMyPosition(String? productId, String? clientId) async {
    await _repository.updateMyCursor(
      userId: userId,
      productId: productId,
      clientId: clientId,
      color: myColor,
      userName: userName,
    );
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }

  @override
  Future<void> close() async {
    await _lockSub?.cancel();
    await _cursorSub?.cancel();
    await _repository.removeMyCursor(userId);
    return super.close();
  }
}
