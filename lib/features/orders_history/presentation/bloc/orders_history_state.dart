import 'package:equatable/equatable.dart';

import '../../../orders_today/domain/entities/order_sheet.dart';
import '../../domain/entities/order_date_info.dart';

sealed class OrdersHistoryState extends Equatable {
  const OrdersHistoryState();

  @override
  List<Object?> get props => [];
}

final class OrdersHistoryInitial extends OrdersHistoryState {
  const OrdersHistoryInitial();
}

final class OrdersHistoryLoading extends OrdersHistoryState {
  const OrdersHistoryLoading();
}

final class OrdersHistoryDatesLoaded extends OrdersHistoryState {
  const OrdersHistoryDatesLoaded({
    required this.allDates,
    required this.filteredDates,
    this.startDate,
    this.endDate,
  });

  final List<OrderDateInfo> allDates;
  final List<OrderDateInfo> filteredDates;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [allDates, filteredDates, startDate, endDate];
}

final class OrdersHistoryDetailLoading extends OrdersHistoryState {
  const OrdersHistoryDetailLoading({required this.selectedDate});

  final DateTime selectedDate;

  @override
  List<Object?> get props => [selectedDate];
}

final class OrdersHistoryDetailLoaded extends OrdersHistoryState {
  const OrdersHistoryDetailLoaded({
    required this.selectedDate,
    required this.orderSheet,
    this.searchFilter = '',
    required this.allDates,
    this.startDate,
    this.endDate,
  });

  final DateTime selectedDate;
  final OrderSheet orderSheet;
  final String searchFilter;
  final List<OrderDateInfo> allDates;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    selectedDate,
    orderSheet,
    searchFilter,
    allDates,
    startDate,
    endDate,
  ];
}

final class OrdersHistoryEmpty extends OrdersHistoryState {
  const OrdersHistoryEmpty();
}

final class OrdersHistoryError extends OrdersHistoryState {
  const OrdersHistoryError({required this.errorType});

  final OrdersHistoryErrorType errorType;

  @override
  List<Object?> get props => [errorType];
}

enum OrdersHistoryErrorType { serverError, unknown }
