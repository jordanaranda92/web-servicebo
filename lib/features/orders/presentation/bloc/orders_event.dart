import 'package:equatable/equatable.dart';

import '../../domain/entities/order_sheet.dart';

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

final class OrdersLoadRequested extends OrdersEvent {
  const OrdersLoadRequested({this.createIfMissing = true, this.date});

  /// When `false`, the BLoC will emit [OrdersNoFile] instead of
  /// auto-creating the document if it doesn't exist yet.
  final bool createIfMissing;

  /// Optional date override used before loading orders.
  final DateTime? date;

  @override
  List<Object?> get props => [createIfMissing, date];
}

final class OrdersCreateFileRequested extends OrdersEvent {
  const OrdersCreateFileRequested();
}

final class OrdersRefreshRequested extends OrdersEvent {
  const OrdersRefreshRequested();
}

final class OrdersCellUpdateRequested extends OrdersEvent {
  const OrdersCellUpdateRequested({
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
final class OrdersRemoteOrderUpdated extends OrdersEvent {
  const OrdersRemoteOrderUpdated({this.orderSheet});

  final OrderSheet? orderSheet;

  @override
  List<Object?> get props => [orderSheet];
}

final class OrdersRemoveClientsRequested extends OrdersEvent {
  const OrdersRemoveClientsRequested({required this.clientIndices});

  final List<int> clientIndices;

  @override
  List<Object?> get props => [clientIndices];
}

final class OrdersRemoveProductsRequested extends OrdersEvent {
  const OrdersRemoveProductsRequested({required this.productIndices});

  final List<int> productIndices;

  @override
  List<Object?> get props => [productIndices];
}

final class OrdersAddClientsRequested extends OrdersEvent {
  const OrdersAddClientsRequested({required this.clientIds});

  final List<String> clientIds;

  @override
  List<Object?> get props => [clientIds];
}

final class OrdersAddProductsRequested extends OrdersEvent {
  const OrdersAddProductsRequested({required this.productIds});

  final List<String> productIds;

  @override
  List<Object?> get props => [productIds];
}

final class OrdersCellFlagUpdateRequested extends OrdersEvent {
  const OrdersCellFlagUpdateRequested({
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

final class OrdersCellNoteUpdateRequested extends OrdersEvent {
  const OrdersCellNoteUpdateRequested({
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

final class OrdersCellRefundUpdateRequested extends OrdersEvent {
  const OrdersCellRefundUpdateRequested({
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

final class OrdersResetOrdersRequested extends OrdersEvent {
  const OrdersResetOrdersRequested({required this.clientIndices});

  final List<int> clientIndices;

  @override
  List<Object?> get props => [clientIndices];
}

final class OrdersSaveInvoicedByRequested extends OrdersEvent {
  const OrdersSaveInvoicedByRequested({
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

final class OrdersClientNoteUpdateRequested extends OrdersEvent {
  const OrdersClientNoteUpdateRequested({
    required this.clientCol,
    required this.note,
  });

  /// Client column index.
  final int clientCol;

  /// Note text, or `null` to remove the note.
  final String? note;

  @override
  List<Object?> get props => [clientCol, note];
}

final class OrdersReplaceClientRequested extends OrdersEvent {
  const OrdersReplaceClientRequested({
    required this.clientCol,
    required this.newClientId,
  });

  /// Column index of the client to replace.
  final int clientCol;

  /// ID of the new client to put in this column.
  final String newClientId;

  @override
  List<Object?> get props => [clientCol, newClientId];
}

/// Fired when the user selects a different date via the date selector dialog.
final class OrdersDateChanged extends OrdersEvent {
  const OrdersDateChanged({required this.date});

  final DateTime date;

  @override
  List<Object?> get props => [date];
}
