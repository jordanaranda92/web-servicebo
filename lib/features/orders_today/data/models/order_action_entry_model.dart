import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_action_entry.dart';

class OrderActionEntryModel {
  final String id;
  final DateTime? timestamp;
  final String userId;
  final String userName;
  final String actionType;
  final Map<String, String> details;

  const OrderActionEntryModel({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.actionType,
    this.details = const {},
  });

  /// Parses an entry from the `entries` array stored in the history document.
  /// The timestamp is an ISO 8601 string.
  factory OrderActionEntryModel.fromMap(String id, Map<String, dynamic> data) {
    final rawDetails = data['details'] as Map<String, dynamic>? ?? {};
    final details = rawDetails.map<String, String>(
      (key, value) => MapEntry(key, (value as String?) ?? ''),
    );

    DateTime? ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs);
    }

    return OrderActionEntryModel(
      id: id,
      timestamp: ts,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      actionType: (data['actionType'] as String?) ?? '',
      details: details,
    );
  }

  OrderActionEntry toEntity() {
    return OrderActionEntry(
      id: id,
      timestamp: timestamp ?? DateTime.now(),
      userId: userId,
      userName: userName,
      actionType: OrderActionType.values.firstWhere(
        (e) => e.name == actionType,
        orElse: () => OrderActionType.quantityChanged,
      ),
      details: details,
    );
  }
}
