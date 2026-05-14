import 'package:equatable/equatable.dart';

import '../../domain/entities/order_sheet.dart';

sealed class OrdersTodayState extends Equatable {
  const OrdersTodayState();

  @override
  List<Object?> get props => [];
}

final class OrdersTodayInitial extends OrdersTodayState {
  const OrdersTodayInitial();
}

final class OrdersTodayLoading extends OrdersTodayState {
  const OrdersTodayLoading();
}

final class OrdersTodayCreating extends OrdersTodayState {
  const OrdersTodayCreating();
}

final class OrdersTodayLoaded extends OrdersTodayState {
  const OrdersTodayLoaded({required this.orderSheet});

  final OrderSheet orderSheet;

  @override
  List<Object?> get props => [orderSheet];
}

final class OrdersTodayNoFile extends OrdersTodayState {
  const OrdersTodayNoFile();
}

final class OrdersTodayError extends OrdersTodayState {
  const OrdersTodayError({required this.errorType});

  final OrdersTodayErrorType errorType;

  @override
  List<Object?> get props => [errorType];
}

enum OrdersTodayErrorType {
  templateNotFound,
  fileSystemError,
  invalidFormat,
  driveNotConfigured,
  configNotAvailable,
  unknown,
}
