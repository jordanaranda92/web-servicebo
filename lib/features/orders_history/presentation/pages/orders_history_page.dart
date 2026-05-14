import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../bloc/orders_history_bloc.dart';
import '../bloc/orders_history_event.dart';
import '../bloc/orders_history_state.dart';
import '../widgets/history_date_list.dart';
import '../widgets/history_empty_state.dart';
import '../widgets/history_error_state.dart';
import '../widgets/history_orders_table.dart';

class OrdersHistoryPage extends StatelessWidget {
  const OrdersHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<OrdersHistoryBloc>()..add(const OrdersHistoryLoadDates()),
      child: const _OrdersHistoryContent(),
    );
  }
}

class _OrdersHistoryContent extends StatefulWidget {
  const _OrdersHistoryContent();

  @override
  State<_OrdersHistoryContent> createState() => _OrdersHistoryContentState();
}

class _OrdersHistoryContentState extends State<_OrdersHistoryContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<OrdersHistoryBloc, OrdersHistoryState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType || previous != current,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state is OrdersHistoryDetailLoaded)
              _buildDetailHeader(context, l10n, state.selectedDate)
            else
              PageHeader(title: l10n.menuOrdersHistory),
            if (state is OrdersHistoryDetailLoaded) ...[
              const SizedBox(height: AppSpacing.md),
              _buildSearchBar(context, l10n, state.searchFilter),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _buildBody(context, l10n, state)),
          ],
        );
      },
    );
  }

  Widget _buildDetailHeader(
    BuildContext context,
    AppLocalizations l10n,
    DateTime date,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formatted = DateFormat(
      "EEEE, d 'de' MMMM 'de' yyyy",
      'es',
    ).format(date);
    final capitalized = formatted[0].toUpperCase() + formatted.substring(1);

    return PageHeader(
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              _searchController.clear();
              context.read<OrdersHistoryBloc>().add(
                const OrdersHistoryBackToList(),
              );
            },
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l10n.ordersHistoryBackToList,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            capitalized,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    AppLocalizations l10n,
    String currentFilter,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SizedBox(
        width: AppDimensions.searchBoxWidth,
        height: AppDimensions.searchBoxHeight,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            context.read<OrdersHistoryBloc>().add(
              OrdersHistorySearchChanged(query: value),
            );
          },
          decoration: InputDecoration(
            hintText: l10n.ordersHistorySearchClient,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      context.read<OrdersHistoryBloc>().add(
                        const OrdersHistorySearchChanged(query: ''),
                      );
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.small),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    OrdersHistoryState state,
  ) {
    return switch (state) {
      OrdersHistoryInitial() || OrdersHistoryLoading() => const Center(
        child: CircularProgressIndicator(),
      ),
      OrdersHistoryEmpty() => const HistoryEmptyState(),
      OrdersHistoryError(:final errorType) => HistoryErrorState(
        errorType: errorType,
        onRetry: () {
          context.read<OrdersHistoryBloc>().add(const OrdersHistoryLoadDates());
        },
      ),
      OrdersHistoryDatesLoaded(:final filteredDates) => HistoryDateList(
        dates: filteredDates,
        onDateSelected: (date) {
          context.read<OrdersHistoryBloc>().add(
            OrdersHistoryDateSelected(date: date),
          );
        },
      ),
      OrdersHistoryDetailLoading() => const Center(
        child: CircularProgressIndicator(),
      ),
      OrdersHistoryDetailLoaded(:final orderSheet, :final searchFilter) =>
        HistoryOrdersTable(orderSheet: orderSheet, searchFilter: searchFilter),
    };
  }
}
