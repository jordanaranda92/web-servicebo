import 'package:equatable/equatable.dart';

sealed class FdCountersState extends Equatable {
  const FdCountersState();

  @override
  List<Object?> get props => [];
}

final class FdCountersInitial extends FdCountersState {
  const FdCountersInitial();
}

final class FdCountersLoading extends FdCountersState {
  const FdCountersLoading();
}

final class FdCountersNotConfigured extends FdCountersState {
  const FdCountersNotConfigured();
}

final class FdCountersLoaded extends FdCountersState {
  const FdCountersLoaded({
    required this.invoicesCount,
    required this.invoicesTotal,
    this.vsYesterday,
    this.vsSameWeekday,
    this.vsLastWeek,
  });

  final int invoicesCount;
  final double invoicesTotal;
  final FdPeriodComparison? vsYesterday;
  final FdPeriodComparison? vsSameWeekday;
  final FdPeriodComparison? vsLastWeek;

  @override
  List<Object?> get props => [
    invoicesCount,
    invoicesTotal,
    vsYesterday,
    vsSameWeekday,
    vsLastWeek,
  ];
}

final class FdCountersError extends FdCountersState {
  const FdCountersError();
}

class FdPeriodComparison extends Equatable {
  const FdPeriodComparison({
    required this.invoicesDiff,
    required this.invoicesTotalDiff,
  });

  final int invoicesDiff;
  final double invoicesTotalDiff;

  @override
  List<Object?> get props => [invoicesDiff, invoicesTotalDiff];
}
