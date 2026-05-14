import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/order_date_info.dart';
import '../../domain/usecases/get_available_dates.dart';
import '../../domain/usecases/get_history_orders.dart';
import 'orders_history_event.dart';
import 'orders_history_state.dart';

class OrdersHistoryBloc extends Bloc<OrdersHistoryEvent, OrdersHistoryState> {
  OrdersHistoryBloc({
    required GetAvailableDates getAvailableDates,
    required GetHistoryOrders getHistoryOrders,
  }) : _getAvailableDates = getAvailableDates,
       _getHistoryOrders = getHistoryOrders,
       super(const OrdersHistoryInitial()) {
    on<OrdersHistoryLoadDates>(_onLoadDates);
    on<OrdersHistoryDateSelected>(_onDateSelected);
    on<OrdersHistoryBackToList>(_onBackToList);
    on<OrdersHistoryDateRangeChanged>(_onDateRangeChanged);
    on<OrdersHistorySearchChanged>(_onSearchChanged);
  }

  final GetAvailableDates _getAvailableDates;
  final GetHistoryOrders _getHistoryOrders;

  Future<void> _onLoadDates(
    OrdersHistoryLoadDates event,
    Emitter<OrdersHistoryState> emit,
  ) async {
    emit(const OrdersHistoryLoading());
    final result = await _getAvailableDates(NoParams());
    result.fold(
      (failure) => emit(OrdersHistoryError(errorType: _mapFailure(failure))),
      (dates) {
        if (dates.isEmpty) {
          emit(const OrdersHistoryEmpty());
        } else {
          emit(OrdersHistoryDatesLoaded(allDates: dates, filteredDates: dates));
        }
      },
    );
  }

  Future<void> _onDateSelected(
    OrdersHistoryDateSelected event,
    Emitter<OrdersHistoryState> emit,
  ) async {
    final currentState = state;
    final allDates = currentState is OrdersHistoryDatesLoaded
        ? currentState.allDates
        : currentState is OrdersHistoryDetailLoaded
        ? currentState.allDates
        : <OrderDateInfo>[];
    final startDate = currentState is OrdersHistoryDatesLoaded
        ? currentState.startDate
        : currentState is OrdersHistoryDetailLoaded
        ? currentState.startDate
        : null;
    final endDate = currentState is OrdersHistoryDatesLoaded
        ? currentState.endDate
        : currentState is OrdersHistoryDetailLoaded
        ? currentState.endDate
        : null;

    emit(OrdersHistoryDetailLoading(selectedDate: event.date));
    final result = await _getHistoryOrders(
      GetHistoryOrdersParams(date: event.date),
    );
    result.fold(
      (failure) => emit(OrdersHistoryError(errorType: _mapFailure(failure))),
      (sheet) => emit(
        OrdersHistoryDetailLoaded(
          selectedDate: event.date,
          orderSheet: sheet,
          allDates: allDates,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  void _onBackToList(
    OrdersHistoryBackToList event,
    Emitter<OrdersHistoryState> emit,
  ) {
    final currentState = state;
    if (currentState is OrdersHistoryDetailLoaded) {
      final filteredDates = _applyDateFilter(
        currentState.allDates,
        currentState.startDate,
        currentState.endDate,
      );
      emit(
        OrdersHistoryDatesLoaded(
          allDates: currentState.allDates,
          filteredDates: filteredDates,
          startDate: currentState.startDate,
          endDate: currentState.endDate,
        ),
      );
    }
  }

  void _onDateRangeChanged(
    OrdersHistoryDateRangeChanged event,
    Emitter<OrdersHistoryState> emit,
  ) {
    final currentState = state;
    if (currentState is OrdersHistoryDatesLoaded) {
      final filteredDates = _applyDateFilter(
        currentState.allDates,
        event.start,
        event.end,
      );
      emit(
        OrdersHistoryDatesLoaded(
          allDates: currentState.allDates,
          filteredDates: filteredDates,
          startDate: event.start,
          endDate: event.end,
        ),
      );
    }
  }

  void _onSearchChanged(
    OrdersHistorySearchChanged event,
    Emitter<OrdersHistoryState> emit,
  ) {
    final currentState = state;
    if (currentState is OrdersHistoryDetailLoaded) {
      emit(
        OrdersHistoryDetailLoaded(
          selectedDate: currentState.selectedDate,
          orderSheet: currentState.orderSheet,
          searchFilter: event.query,
          allDates: currentState.allDates,
          startDate: currentState.startDate,
          endDate: currentState.endDate,
        ),
      );
    }
  }

  List<OrderDateInfo> _applyDateFilter(
    List<OrderDateInfo> allDates,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null && end == null) return allDates;
    return allDates.where((info) {
      if (start != null && info.date.isBefore(start)) return false;
      if (end != null && info.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  OrdersHistoryErrorType _mapFailure(Failure failure) {
    if (failure is ServerFailure) {
      return OrdersHistoryErrorType.serverError;
    }
    return OrdersHistoryErrorType.unknown;
  }
}
