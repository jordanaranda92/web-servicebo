import 'package:equatable/equatable.dart';

import '../../domain/entities/cell_lock.dart';
import '../../domain/entities/remote_cursor.dart';

class OrdersPresenceState extends Equatable {
  final Map<String, CellLock> locks;
  final Map<String, RemoteCursor> cursors;
  final int connectedUsers;

  const OrdersPresenceState({
    this.locks = const {},
    this.cursors = const {},
    this.connectedUsers = 0,
  });

  OrdersPresenceState copyWith({
    Map<String, CellLock>? locks,
    Map<String, RemoteCursor>? cursors,
    int? connectedUsers,
  }) {
    return OrdersPresenceState(
      locks: locks ?? this.locks,
      cursors: cursors ?? this.cursors,
      connectedUsers: connectedUsers ?? this.connectedUsers,
    );
  }

  @override
  List<Object?> get props => [locks, cursors, connectedUsers];
}
