/// DTO for a cursor entry in Firebase RTDB.
class CursorInfo {
  final String? productId;
  final String? clientId;
  final String color;
  final String? userName;

  const CursorInfo({
    this.productId,
    this.clientId,
    required this.color,
    this.userName,
  });

  factory CursorInfo.fromMap(Map<dynamic, dynamic> map) {
    return CursorInfo(
      productId: map['pid'] as String?,
      clientId: map['cid'] as String?,
      color: (map['color'] as String?) ?? '#9E9E9E',
      userName: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (productId != null) 'pid': productId,
    if (clientId != null) 'cid': clientId,
    'color': color,
    if (userName != null) 'name': userName,
  };
}

/// Represents a cursor change event from RTDB.
class CursorUpdate {
  final String userId;
  final CursorInfo? cursor;
  final bool removed;

  const CursorUpdate({required this.userId, this.cursor, this.removed = false});
}
