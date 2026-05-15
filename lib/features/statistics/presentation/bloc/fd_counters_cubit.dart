import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/usecases/get_invoices_by_date_range.dart';
import 'fd_counters_state.dart';

class FdCountersCubit extends Cubit<FdCountersState> {
  FdCountersCubit({required GetInvoicesByDateRange getInvoicesByDateRange})
    : _getInvoicesByDateRange = getInvoicesByDateRange,
      super(const FdCountersInitial());

  final GetInvoicesByDateRange _getInvoicesByDateRange;

  Future<void> load() async {
    emit(const FdCountersLoading());

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate date ranges: this week (Mon→today) and last week (Mon→Sun).
    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final mondayLastWeek = mondayThisWeek.subtract(const Duration(days: 7));
    final sundayLastWeek = mondayThisWeek.subtract(const Duration(days: 1));

    // Fetch both ranges in parallel.
    final results = await Future.wait([
      _getInvoicesByDateRange(
        DateRangeParams(
          minDate: _dateStr(mondayThisWeek),
          maxDate: _dateStr(today),
        ),
      ),
      _getInvoicesByDateRange(
        DateRangeParams(
          minDate: _dateStr(mondayLastWeek),
          maxDate: _dateStr(sundayLastWeek),
        ),
      ),
    ]);
    if (isClosed) return;

    final thisWeekResult = results[0];
    final lastWeekResult = results[1];

    if (thisWeekResult.isLeft() || lastWeekResult.isLeft()) {
      emit(const FdCountersError());
      return;
    }

    final allInv = [
      ...thisWeekResult.getOrElse((_) => []),
      ...lastWeekResult.getOrElse((_) => []),
    ];

    final todayStr = _dateStr(today);

    // Today counts
    final todayInv = allInv.where((e) => e.date == todayStr).toList();
    final invCount = todayInv.length;
    final invTotal = _sumInvoices(todayInv);

    // Yesterday
    final yesterday = today.subtract(const Duration(days: 1));
    final vsYesterday = _compareSingleDay(allInv, today, yesterday);

    // Same weekday last week
    final sameWeekdayLastWeek = today.subtract(const Duration(days: 7));
    final vsSameWeekday = _compareSingleDay(allInv, today, sameWeekdayLastWeek);

    // Current week (Mon→today) vs last week (Mon→same weekday)
    final dayOfWeek = today.weekday - 1; // 0-based offset from Monday
    final equivalentDayLastWeek = mondayLastWeek.add(Duration(days: dayOfWeek));
    final vsLastWeek = _compareRange(
      allInv,
      mondayThisWeek,
      today,
      mondayLastWeek,
      equivalentDayLastWeek,
    );

    emit(
      FdCountersLoaded(
        invoicesCount: invCount,
        invoicesTotal: invTotal,
        vsYesterday: vsYesterday,
        vsSameWeekday: vsSameWeekday,
        vsLastWeek: vsLastWeek,
      ),
    );
  }

  // --- helpers ---

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _inRange(String? date, DateTime start, DateTime end) {
    if (date == null) return false;
    final s = _dateStr(start);
    final e = _dateStr(end);
    return date.compareTo(s) >= 0 && date.compareTo(e) <= 0;
  }

  static double _sumInvoices(List<Invoice> invoices) =>
      invoices.fold<double>(0, (sum, e) => sum + (e.total ?? 0));

  static FdPeriodComparison _compareSingleDay(
    List<Invoice> allInv,
    DateTime current,
    DateTime previous,
  ) {
    final curStr = _dateStr(current);
    final prevStr = _dateStr(previous);

    final curInvList = allInv.where((e) => e.date == curStr).toList();
    final prevInvList = allInv.where((e) => e.date == prevStr).toList();

    return FdPeriodComparison(
      invoicesDiff: curInvList.length - prevInvList.length,
      invoicesTotalDiff: _sumInvoices(curInvList) - _sumInvoices(prevInvList),
    );
  }

  static FdPeriodComparison _compareRange(
    List<Invoice> allInv,
    DateTime curStart,
    DateTime curEnd,
    DateTime prevStart,
    DateTime prevEnd,
  ) {
    final curInvList = allInv
        .where((e) => _inRange(e.date, curStart, curEnd))
        .toList();
    final prevInvList = allInv
        .where((e) => _inRange(e.date, prevStart, prevEnd))
        .toList();

    return FdPeriodComparison(
      invoicesDiff: curInvList.length - prevInvList.length,
      invoicesTotalDiff: _sumInvoices(curInvList) - _sumInvoices(prevInvList),
    );
  }
}
