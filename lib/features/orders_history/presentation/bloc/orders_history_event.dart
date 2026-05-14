import 'package:equatable/equatable.dart';

sealed class OrdersHistoryEvent extends Equatable {
  const OrdersHistoryEvent();

  @override
  List<Object?> get props => [];
}

final class OrdersHistoryLoadDates extends OrdersHistoryEvent {
  const OrdersHistoryLoadDates();
}

final class OrdersHistoryDateSelected extends OrdersHistoryEvent {
  const OrdersHistoryDateSelected({required this.date});

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

final class OrdersHistoryBackToList extends OrdersHistoryEvent {
  const OrdersHistoryBackToList();
}

final class OrdersHistoryDateRangeChanged extends OrdersHistoryEvent {
  const OrdersHistoryDateRangeChanged({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  List<Object?> get props => [start, end];
}

final class OrdersHistorySearchChanged extends OrdersHistoryEvent {
  const OrdersHistorySearchChanged({required this.query});

  final String query;

  @override
  List<Object?> get props => [query];
}
