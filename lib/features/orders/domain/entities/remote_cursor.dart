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
    this.color = const Color(0xFF9E9E9E),
  });

  /// Returns a copy with a different color assigned locally.
  RemoteCursor withColor(Color newColor) => RemoteCursor(
    userId: userId,
    userName: userName,
    productId: productId,
    clientId: clientId,
    color: newColor,
  );

  @override
  List<Object?> get props => [userId, userName, productId, clientId, color];
}
