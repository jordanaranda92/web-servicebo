import 'package:equatable/equatable.dart';

import '../../domain/entities/invoice.dart';

// ─── Invoice Filters ───────────────────────────────────────────────────

class InvoiceFilters extends Equatable {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String> statuses;
  final Set<String> clients;
  final String textQuery;

  const InvoiceFilters({
    this.dateFrom,
    this.dateTo,
    this.statuses = const {},
    this.clients = const {},
    this.textQuery = '',
  });

  factory InvoiceFilters.defaultFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return InvoiceFilters(dateFrom: today, dateTo: today);
  }

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      statuses.isNotEmpty ||
      clients.isNotEmpty ||
      textQuery.isNotEmpty;

  bool get hasDateFilters => dateFrom != null || dateTo != null;

  int get activeFilterCount =>
      (dateFrom != null ? 1 : 0) +
      (dateTo != null ? 1 : 0) +
      statuses.length +
      clients.length;

  InvoiceFilters copyWith({
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    Set<String>? statuses,
    Set<String>? clients,
    String? textQuery,
  }) {
    return InvoiceFilters(
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      statuses: statuses ?? this.statuses,
      clients: clients ?? this.clients,
      textQuery: textQuery ?? this.textQuery,
    );
  }

  @override
  List<Object?> get props => [dateFrom, dateTo, statuses, clients, textQuery];
}

// ─── States ────────────────────────────────────────────────────────────

abstract class InvoicesState extends Equatable {
  const InvoicesState();

  @override
  List<Object?> get props => [];
}

class InvoicesInitial extends InvoicesState {
  const InvoicesInitial();
}

class InvoicesLoading extends InvoicesState {
  const InvoicesLoading();
}

class InvoicesLoaded extends InvoicesState {
  final List<Invoice> allInvoices;
  final List<Invoice> filteredInvoices;
  final InvoiceFilters filters;
  final bool hasMore;
  final bool isLoadingMore;

  const InvoicesLoaded({
    required this.allInvoices,
    required this.filteredInvoices,
    required this.filters,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  List<String> get availableClients {
    final names = <String>{};
    for (final invoice in allInvoices) {
      final name = invoice.contactName;
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  @override
  List<Object?> get props => [
    allInvoices,
    filteredInvoices,
    filters,
    hasMore,
    isLoadingMore,
  ];
}

class InvoicesError extends InvoicesState {
  final InvoicesErrorType errorType;

  const InvoicesError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum InvoicesErrorType { configNotFound, network, server, unknown }
