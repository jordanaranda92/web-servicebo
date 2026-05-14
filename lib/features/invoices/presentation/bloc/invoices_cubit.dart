import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../clients/domain/usecases/get_clients.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/usecases/get_invoices.dart';
import '../../domain/usecases/get_invoices_by_date_range.dart';
import 'invoices_state.dart';

class InvoicesCubit extends Cubit<InvoicesState> {
  final GetInvoices _getInvoices;
  final GetInvoicesByDateRange _getInvoicesByDateRange;
  final GetClients _getClients;

  static const _apiPageSize = 500;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  InvoiceFilters _lastFilters = InvoiceFilters.defaultFilters();

  /// Cache: FD contact UUID → client display name (title)
  Map<String, String> _clientNameMap = {};

  InvoicesCubit(
    this._getInvoices,
    this._getInvoicesByDateRange,
    this._getClients,
  ) : super(const InvoicesInitial());

  Future<void> loadInvoices({InvoiceFilters? filters}) async {
    final f = filters ?? _lastFilters;
    _lastFilters = f;
    emit(const InvoicesLoading());

    // Load clients in parallel (best-effort, cached after first load)
    if (_clientNameMap.isEmpty) {
      await _loadClientNameMap();
    }

    if (f.dateFrom != null && f.dateTo != null) {
      final result = await _getInvoicesByDateRange(
        DateRangeParams(
          minDate: _dateFmt.format(f.dateFrom!),
          maxDate: _dateFmt.format(f.dateTo!),
        ),
      );
      result.fold(
        (failure) => emit(InvoicesError(errorType: _mapFailure(failure))),
        (invoices) {
          final resolved = _resolveContactNames(invoices);
          final sorted = _sortByDateDesc(resolved);
          final filtered = _applyClientSideFilters(sorted, f);
          emit(
            InvoicesLoaded(
              allInvoices: sorted,
              filteredInvoices: filtered,
              filters: f,
              hasMore: invoices.length == _apiPageSize,
            ),
          );
        },
      );
    } else {
      final result = await _getInvoices(NoParams());
      result.fold(
        (failure) => emit(InvoicesError(errorType: _mapFailure(failure))),
        (invoices) {
          final resolved = _resolveContactNames(invoices);
          final sorted = _sortByDateDesc(resolved);
          final filtered = _applyClientSideFilters(sorted, f);
          emit(
            InvoicesLoaded(
              allInvoices: sorted,
              filteredInvoices: filtered,
              filters: f,
              hasMore: invoices.length == _apiPageSize,
            ),
          );
        },
      );
    }
  }

  void applyFilters(InvoiceFilters newFilters) {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final datesChanged =
        newFilters.dateFrom != s.filters.dateFrom ||
        newFilters.dateTo != s.filters.dateTo;

    if (datesChanged) {
      loadInvoices(filters: newFilters);
    } else {
      _lastFilters = newFilters;
      final filtered = _applyClientSideFilters(s.allInvoices, newFilters);
      emit(
        InvoicesLoaded(
          allInvoices: s.allInvoices,
          filteredInvoices: filtered,
          filters: newFilters,
          hasMore: s.hasMore,
        ),
      );
    }
  }

  void filterByText(String query) {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final newFilters = s.filters.copyWith(textQuery: query);
    _lastFilters = newFilters;
    final filtered = _applyClientSideFilters(s.allInvoices, newFilters);
    emit(
      InvoicesLoaded(
        allInvoices: s.allInvoices,
        filteredInvoices: filtered,
        filters: newFilters,
        hasMore: s.hasMore,
      ),
    );
  }

  void removeStatusFilter(String status) {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final newStatuses = Set<String>.from(s.filters.statuses)..remove(status);
    final newFilters = s.filters.copyWith(statuses: newStatuses);
    _lastFilters = newFilters;
    final filtered = _applyClientSideFilters(s.allInvoices, newFilters);
    emit(
      InvoicesLoaded(
        allInvoices: s.allInvoices,
        filteredInvoices: filtered,
        filters: newFilters,
        hasMore: s.hasMore,
      ),
    );
  }

  void removeClientFilter(String client) {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final newClients = Set<String>.from(s.filters.clients)..remove(client);
    final newFilters = s.filters.copyWith(clients: newClients);
    _lastFilters = newFilters;
    final filtered = _applyClientSideFilters(s.allInvoices, newFilters);
    emit(
      InvoicesLoaded(
        allInvoices: s.allInvoices,
        filteredInvoices: filtered,
        filters: newFilters,
        hasMore: s.hasMore,
      ),
    );
  }

  void removeDateFromFilter() {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final newFilters = s.filters.copyWith(dateFrom: () => null);
    if (newFilters.dateTo == null) {
      // Both dates removed → full load
      loadInvoices(filters: newFilters);
    } else {
      // Only dateFrom removed → reload with just dateTo
      loadInvoices(filters: newFilters);
    }
  }

  void removeDateToFilter() {
    final s = state;
    if (s is! InvoicesLoaded) return;

    final newFilters = s.filters.copyWith(dateTo: () => null);
    if (newFilters.dateFrom == null) {
      loadInvoices(filters: newFilters);
    } else {
      loadInvoices(filters: newFilters);
    }
  }

  void clearAllFilters() {
    loadInvoices(filters: const InvoiceFilters());
  }

  // ─── Private helpers ─────────────────────────────────────────────────

  List<Invoice> _sortByDateDesc(List<Invoice> invoices) {
    const statusOrder = {
      'draft': 0,
      'pending': 1,
      'paid': 2,
      'overdue': 3,
      'voided': 4,
      'overpaid': 5,
    };
    return List.of(invoices)..sort((a, b) {
      final dateCompare = (b.date ?? '').compareTo(a.date ?? '');
      if (dateCompare != 0) return dateCompare;
      final aOrder = statusOrder[a.status] ?? 99;
      final bOrder = statusOrder[b.status] ?? 99;
      return aOrder.compareTo(bOrder);
    });
  }

  List<Invoice> _applyClientSideFilters(
    List<Invoice> invoices,
    InvoiceFilters filters,
  ) {
    return invoices.where((invoice) {
      if (filters.statuses.isNotEmpty) {
        final status = invoice.status?.toLowerCase() ?? '';
        if (!filters.statuses.contains(status)) return false;
      }
      if (filters.clients.isNotEmpty) {
        if (!filters.clients.contains(invoice.contactName)) return false;
      }
      if (filters.textQuery.isNotEmpty) {
        final q = filters.textQuery.trim().toLowerCase();
        final docNumber = invoice.docNumber.toLowerCase();
        final client = invoice.contactName?.toLowerCase() ?? '';
        final subtotal = invoice.subtotal?.toStringAsFixed(2) ?? '';
        final total = invoice.total?.toStringAsFixed(2) ?? '';
        if (!docNumber.contains(q) &&
            !client.contains(q) &&
            !subtotal.contains(q) &&
            !total.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  InvoicesErrorType _mapFailure(Failure failure) {
    if (failure is ConfigNotFoundFailure) {
      return InvoicesErrorType.configNotFound;
    }
    if (failure is NetworkFailure) return InvoicesErrorType.network;
    if (failure is ServerFailure) return InvoicesErrorType.server;
    return InvoicesErrorType.unknown;
  }

  Future<void> _loadClientNameMap() async {
    final result = await _getClients(NoParams());
    result.fold(
      (_) {}, // best-effort: if clients fail, keep using invoice contactName
      (clients) {
        _clientNameMap = {
          for (final c in clients)
            if (c.facturaDirectaUuid.isNotEmpty) c.facturaDirectaUuid: c.name,
        };
      },
    );
  }

  List<Invoice> _resolveContactNames(List<Invoice> invoices) {
    if (_clientNameMap.isEmpty) return invoices;
    return invoices.map((invoice) {
      final contactId = invoice.contactId;
      if (contactId != null && _clientNameMap.containsKey(contactId)) {
        return invoice.copyWith(contactName: _clientNameMap[contactId]);
      }
      return invoice;
    }).toList();
  }
}
