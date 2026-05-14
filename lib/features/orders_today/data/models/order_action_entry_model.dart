import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/order_action_entry.dart';

class OrderActionEntryModel {
  final String id;
  final Timestamp? timestamp;
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

  factory OrderActionEntryModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDetails = data['details'] as Map<String, dynamic>? ?? {};
    final details = rawDetails.map<String, String>(
      (key, value) => MapEntry(key, (value as String?) ?? ''),
    );

    return OrderActionEntryModel(
      id: id,
      timestamp: data['timestamp'] as Timestamp?,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      actionType: (data['actionType'] as String?) ?? '',
      details: details,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
      'actionType': actionType,
      'details': details,
    };
  }

  OrderActionEntry toEntity() {
    return OrderActionEntry(
      id: id,
      timestamp: timestamp?.toDate() ?? DateTime.now(),
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
