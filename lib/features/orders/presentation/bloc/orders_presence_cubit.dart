import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cell_lock.dart';
import '../../domain/entities/remote_cursor.dart';
import '../../domain/repositories/orders_presence_repository.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/category_color_utils.dart';
import 'orders_presence_state.dart';

class OrdersPresenceCubit extends Cubit<OrdersPresenceState> {
  OrdersPresenceCubit({
    required OrdersPresenceRepository repository,
    required this.userId,
    required this.userName,
    required this.userColor,
    required Future<String?> Function(String uid) resolveUserColor,
    required String initialDateKey,
  }) : _repository = repository,
       _resolveUserColor = resolveUserColor,
       _activeDateKey = initialDateKey,
       super(const OrdersPresenceState());

  final OrdersPresenceRepository _repository;
  final String userId;
  final String userName;

  StreamSubscription<CellLockChange>? _lockSub;
  StreamSubscription<RemoteCursorChange>? _cursorSub;

  /// The RTDB date node currently subscribed to.
  String _activeDateKey;

  /// Persistent color for the current user (from Firestore).
  final Color userColor;

  /// Alias for backward-compat: current user's persistent color.
  Color get myColor => userColor;

  final Future<String?> Function(String uid) _resolveUserColor;

  static final Color _fallbackColor = PresenceColors.palette.first;

  /// Cache of resolved remote user colors (uid → Color).
  final Map<String, Color> _remoteColorCache = {};

  /// Resolve a remote user's color from Firestore, with cache.
  Future<Color> _getRemoteColor(String uid) async {
    if (_remoteColorCache.containsKey(uid)) return _remoteColorCache[uid]!;
    try {
      final hex = await _resolveUserColor(uid);
      final color = tryParseHex(hex) ?? _fallbackColor;
      _remoteColorCache[uid] = color;
      return color;
    } on Exception {
      _remoteColorCache[uid] = _fallbackColor;
      return _fallbackColor;
    }
  }

  /// Initialize presence: register cursor, subscribe to changes.
  Future<void> init() async {
    try {
      await _repository.setupDisconnectCleanup(userId, dateKey: _activeDateKey);
      await _repository.updateMyCursor(
        userId: userId,
        productId: null,
        clientId: null,
        userName: userName,
        dateKey: _activeDateKey,
      );
      await _repository.cleanExpiredLocks(dateKey: _activeDateKey);

      _lockSub = _repository
          .onLockChanged(dateKey: _activeDateKey)
          .listen(_onLockUpdate);
      _cursorSub = _repository
          .onCursorChanged(dateKey: _activeDateKey)
          .listen(_onCursorUpdate);

      // Load initial snapshots
      final lockEntities = await _repository.getAllLocks(
        dateKey: _activeDateKey,
      );
      final allCursors = await _repository.getAllCursors(
        dateKey: _activeDateKey,
      );

      // Remove own cursor from remote list and resolve persistent colors
      final cursorEntities = <String, RemoteCursor>{};
      for (final entry in allCursors.entries) {
        if (entry.key == userId) continue;
        final color = await _getRemoteColor(entry.key);
        cursorEntities[entry.key] = entry.value.withColor(color);
      }

      if (isClosed) return;
      emit(
        OrdersPresenceState(
          locks: lockEntities,
          cursors: cursorEntities,
          connectedUsers: allCursors.length,
        ),
      );
    } on Exception catch (_) {
      // RTDB unavailable — presence features degrade gracefully
    }
  }

  /// Switch presence to a different date.
  ///
  /// Cleans up cursor/locks from the previous date node, resets state,
  /// and re-initializes presence on the new date node.
  Future<void> switchDate(String newDateKey) async {
    if (newDateKey == _activeDateKey) return;

    // 1. Cancel stream subscriptions
    await _lockSub?.cancel();
    _lockSub = null;
    await _cursorSub?.cancel();
    _cursorSub = null;

    // 2. Clean up presence on the old date node
    await _repository.removeMyCursor(userId, dateKey: _activeDateKey);

    // 3. Switch to the new date
    _activeDateKey = newDateKey;

    // 4. Reset state
    if (!isClosed) {
      emit(const OrdersPresenceState());
    }

    // 5. Re-initialize on the new date node
    await init();
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

  void _onCursorUpdate(RemoteCursorChange change) async {
    if (isClosed) return;

    if (change.removed) {
      final newCursors = Map<String, RemoteCursor>.from(state.cursors)
        ..remove(change.userId);
      _remoteColorCache.remove(change.userId);
      emit(
        state.copyWith(
          cursors: newCursors,
          connectedUsers: newCursors.length + 1,
        ),
      );
    } else if (change.cursor case final cursor?) {
      if (change.userId == userId) {
        // Don't add own cursor to remote list, but count it
        emit(state.copyWith(connectedUsers: state.cursors.length + 1));
      } else {
        final color = await _getRemoteColor(change.userId);
        if (isClosed) return;
        // Re-read state AFTER await to avoid overwriting concurrent updates
        final newCursors = Map<String, RemoteCursor>.from(state.cursors)
          ..[change.userId] = cursor.withColor(color);
        emit(
          state.copyWith(
            cursors: newCursors,
            connectedUsers: newCursors.length + 1,
          ),
        );
      }
    }
  }

  /// Attempt to acquire a lock on [cellKey]. Returns `true` if acquired.
  Future<bool> acquireLock(String cellKey) async {
    return _repository.acquireLock(cellKey, userId, dateKey: _activeDateKey);
  }

  /// Release the lock on [cellKey].
  Future<void> releaseLock(String cellKey) async {
    await _repository.releaseLock(cellKey, dateKey: _activeDateKey);
  }

  /// Update the current user's cursor position.
  Future<void> updateMyPosition(String? productId, String? clientId) async {
    await _repository.updateMyCursor(
      userId: userId,
      productId: productId,
      clientId: clientId,
      userName: userName,
      dateKey: _activeDateKey,
    );
  }

  @override
  Future<void> close() async {
    await _lockSub?.cancel();
    await _cursorSub?.cancel();
    await _repository.removeMyCursor(userId, dateKey: _activeDateKey);
    return super.close();
  }
}
