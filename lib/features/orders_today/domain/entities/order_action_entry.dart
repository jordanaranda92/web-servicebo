import 'package:equatable/equatable.dart';

/// Types of actions that can be recorded in the order action history.
enum OrderActionType {
  quantityChanged,
  stockChanged,
  compensationMarked,
  compensationUnmarked,
  reservationMarked,
  reservationUnmarked,
  strictStockMarked,
  strictStockUnmarked,
  refundAdded,
  refundEdited,
  refundRemoved,
  ordersReset,
  clientsAdded,
  clientsRemoved,
  productsAdded,
  productsRemoved,
  orderSheetCreated,
  orderSheetGenerated,
  provisionalInvoiceGenerated,
}

/// Immutable entity representing a single action in the order history.
class OrderActionEntry extends Equatable {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final OrderActionType actionType;
  final Map<String, String> details;

  const OrderActionEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.actionType,
    this.details = const {},
  });

  @override
  List<Object?> get props => [
    id,
    timestamp,
    userId,
    userName,
    actionType,
    details,
  ];
}
