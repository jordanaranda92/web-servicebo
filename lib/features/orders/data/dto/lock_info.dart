/// DTO for a lock entry in Firebase RTDB.
class LockInfo {
  final String user;
  final int timestamp;

  const LockInfo({required this.user, required this.timestamp});

  factory LockInfo.fromMap(Map<dynamic, dynamic> map) {
    return LockInfo(
      user: (map['user'] as String?) ?? '',
      timestamp: (map['ts'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'user': user, 'ts': timestamp};
}

/// Represents a lock change event from RTDB.
class LockUpdate {
  final String key;
  final LockInfo? lock;
  final bool removed;

  const LockUpdate({required this.key, this.lock, this.removed = false});
}
