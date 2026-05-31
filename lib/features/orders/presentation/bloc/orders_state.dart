import 'package:equatable/equatable.dart';

import '../../domain/entities/order_sheet.dart';

sealed class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

final class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

final class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

final class OrdersCreating extends OrdersState {
  const OrdersCreating();
}

final class OrdersLoaded extends OrdersState {
  const OrdersLoaded({required this.orderSheet, required this.activeDate});

  final OrderSheet orderSheet;
  final DateTime activeDate;

  @override
  List<Object?> get props => [orderSheet, activeDate];
}

final class OrdersNoFile extends OrdersState {
  const OrdersNoFile();
}

final class OrdersError extends OrdersState {
  const OrdersError({required this.errorType});

  final OrdersErrorType errorType;

  @override
  List<Object?> get props => [errorType];
}

enum OrdersErrorType {
  templateNotFound,
  fileSystemError,
  invalidFormat,
  driveNotConfigured,
  configNotAvailable,
  unknown,
}
