import 'package:equatable/equatable.dart';

import '../../domain/entities/order_sheet.dart';

sealed class OrdersTodayEvent extends Equatable {
  const OrdersTodayEvent();

  @override
  List<Object?> get props => [];
}

final class OrdersTodayLoadRequested extends OrdersTodayEvent {
  const OrdersTodayLoadRequested({this.createIfMissing = true});

  /// When `false`, the BLoC will emit [OrdersTodayNoFile] instead of
  /// auto-creating the document if it doesn't exist yet.
  final bool createIfMissing;

  @override
  List<Object?> get props => [createIfMissing];
}

final class OrdersTodayCreateFileRequested extends OrdersTodayEvent {
  const OrdersTodayCreateFileRequested();
}

final class OrdersTodayRefreshRequested extends OrdersTodayEvent {
  const OrdersTodayRefreshRequested();
}

final class OrdersTodayCellUpdateRequested extends OrdersTodayEvent {
  const OrdersTodayCellUpdateRequested({
    required this.productRow,
    required this.clientCol,
    required this.value,
  });

  final int productRow;
  final int clientCol;
  final num value;

  @override
  List<Object?> get props => [productRow, clientCol, value];
}

/// Fired when the Firestore listener emits an updated OrderSheet.
final class OrdersTodayRemoteOrderUpdated extends OrdersTodayEvent {
  const OrdersTodayRemoteOrderUpdated({this.orderSheet});

  final OrderSheet? orderSheet;

  @override
  List<Object?> get props => [orderSheet];
}

final class OrdersTodayRemoveClientsRequested extends OrdersTodayEvent {
  const OrdersTodayRemoveClientsRequested({required this.clientIndices});

  final List<int> clientIndices;

  @override
  List<Object?> get props => [clientIndices];
}

final class OrdersTodayRemoveProductsRequested extends OrdersTodayEvent {
  const OrdersTodayRemoveProductsRequested({required this.productIndices});

  final List<int> productIndices;

  @override
  List<Object?> get props => [productIndices];
}

final class OrdersTodayAddClientsRequested extends OrdersTodayEvent {
  const OrdersTodayAddClientsRequested({required this.clientIds});

  final List<String> clientIds;

  @override
  List<Object?> get props => [clientIds];
}

final class OrdersTodayAddProductsRequested extends OrdersTodayEvent {
  const OrdersTodayAddProductsRequested({required this.productIds});

  final List<String> productIds;

  @override
  List<Object?> get props => [productIds];
}

final class OrdersTodayCellFlagUpdateRequested extends OrdersTodayEvent {
  const OrdersTodayCellFlagUpdateRequested({
    required this.productRow,
    required this.clientCol,
    required this.flagType,
  });

  /// Product index in the sheet.
  final int productRow;

  /// Client column index, or `null` for strict-stock flag.
  final int? clientCol;

  /// Flag type: `"compensation"`, `"reservation"`, `"strictStock"`,
  /// or `null` to remove a flag.
  final String? flagType;

  @override
  List<Object?> get props => [productRow, clientCol, flagType];
}

final class OrdersTodayCellNoteUpdateRequested extends OrdersTodayEvent {
  const OrdersTodayCellNoteUpdateRequested({
    required this.productRow,
    required this.clientCol,
    required this.note,
  });

  /// Product index in the sheet.
  final int productRow;

  /// Client column index.
  final int clientCol;

  /// Note text, or `null` to remove the note.
  final String? note;

  @override
  List<Object?> get props => [productRow, clientCol, note];
}

final class OrdersTodayCellRefundUpdateRequested extends OrdersTodayEvent {
  const OrdersTodayCellRefundUpdateRequested({
    required this.productRow,
    required this.clientCol,
    required this.quantity,
  });

  final int productRow;
  final int clientCol;

  /// Refund quantity, or `null` to remove the refund.
  final num? quantity;

  @override
  List<Object?> get props => [productRow, clientCol, quantity];
}

final class OrdersTodayResetOrdersRequested extends OrdersTodayEvent {
  const OrdersTodayResetOrdersRequested({required this.clientIndices});

  final List<int> clientIndices;

  @override
  List<Object?> get props => [clientIndices];
}

final class OrdersTodaySaveInvoicedByRequested extends OrdersTodayEvent {
  const OrdersTodaySaveInvoicedByRequested({
    required this.clientId,
    required this.userId,
    required this.userName,
    required this.color,
  });

  final String clientId;
  final String userId;
  final String userName;
  final String color;

  @override
  List<Object?> get props => [clientId, userId, userName, color];
}
