import 'package:equatable/equatable.dart';

/// Represents a lock held on a cell by a user.
class CellLock extends Equatable {
  final String cellKey;
  final String user;
  final DateTime timestamp;

  const CellLock({
    required this.cellKey,
    required this.user,
    required this.timestamp,
  });

  /// A lock is considered expired after 60 seconds.
  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > 60;

  @override
  List<Object?> get props => [cellKey, user, timestamp];
}
