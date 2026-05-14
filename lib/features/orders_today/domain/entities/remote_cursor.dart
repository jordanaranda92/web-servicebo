import 'dart:ui';

import 'package:equatable/equatable.dart';

/// Represents a remote user's cursor position in the orders table.
class RemoteCursor extends Equatable {
  final String userId;
  final String userName;
  final String? productId;
  final String? clientId;
  final Color color;

  const RemoteCursor({
    required this.userId,
    required this.userName,
    this.productId,
    this.clientId,
    required this.color,
  });

  @override
  List<Object?> get props => [userId, userName, productId, clientId, color];
}
