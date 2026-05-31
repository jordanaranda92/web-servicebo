import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/app_date_formats.dart';
import '../../domain/usecases/get_today_orders.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../models/client_order_summary.dart';
import 'order_client_card.dart';
import 'order_date_selector_dialog.dart';
import 'orders_empty_state.dart';
import 'orders_error_state.dart';
import 'orders_preparing_state.dart';

/// Read-only mobile view for today's orders.
///
/// Listens to [OrdersBloc] and renders a scrollable list of
/// [OrderClientCard] widgets — one per client with relevant order data.
class OrdersMobileView extends StatefulWidget {
  const OrdersMobileView({super.key});

  @override
  State<OrdersMobileView> createState() => _OrdersMobileViewState();
}

class _OrdersMobileViewState extends State<OrdersMobileView> {
  /// Index of the currently expanded card, or -1 if none.
  int _expandedIndex = -1;

  String _formatDate(DateTime date) {
    final formatted = AppDateFormats.dateWithDay().format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (previous, current) {
        // Rebuild AppBar subtitle when active date changes.
        final prevDate = previous is OrdersLoaded ? previous.activeDate : null;
        final currDate = current is OrdersLoaded ? current.activeDate : null;
        return previous.runtimeType != current.runtimeType ||
            previous != current ||
            prevDate != currDate;
      },
      builder: (context, state) {
        final bloc = context.read<OrdersBloc>();
        final activeDate = bloc.activeDate;
        final dateText = _formatDate(activeDate);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            leading: Builder(
              builder: (scaffoldContext) {
                return IconButton(
                  onPressed: () {
                    // The nearest Scaffold is this page's own (no drawer).
                    // Walk up to the shell's Scaffold which owns the drawer.
                    ScaffoldState? scaffold;
                    scaffoldContext.visitAncestorElements((element) {
                      if (element is StatefulElement &&
                          element.state is ScaffoldState) {
                        final s = element.state as ScaffoldState;
                        if (s.hasDrawer) {
                          scaffold = s;
                          return false; // stop
                        }
                      }
                      return true; // keep going
                    });
                    scaffold?.openDrawer();
                  },
                  icon: const Icon(Icons.menu_rounded),
                );
              },
            ),
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.menuOrders,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dateText,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            titleSpacing: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                tooltip: l10n.ordersDateSelectorTitle,
                onPressed: () => _openDateSelector(context),
              ),
            ],
          ),
          body: _buildBody(context, state, l10n, colorScheme, textTheme),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    OrdersState state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return switch (state) {
      OrdersInitial() ||
      OrdersLoading() => const Center(child: CircularProgressIndicator()),
      OrdersCreating() => const OrdersPreparingState(),
      OrdersNoFile() => OrdersEmptyState(
        onCreateFile: () =>
            context.read<OrdersBloc>().add(const OrdersCreateFileRequested()),
      ),
      OrdersError(:final errorType) => OrdersErrorState(
        errorType: errorType,
        onRetry: () =>
            context.read<OrdersBloc>().add(const OrdersRefreshRequested()),
      ),
      OrdersLoaded(:final orderSheet) => () {
        final summaries = buildClientSummaries(orderSheet);
        if (summaries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: AppIconSizes.xl,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.ordersMobileNoOrders,
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl,
          ),
          itemCount: summaries.length,
          itemBuilder: (context, index) => OrderClientCard(
            summary: summaries[index],
            isExpanded: _expandedIndex == index,
            onToggle: () {
              setState(() {
                _expandedIndex = _expandedIndex == index ? -1 : index;
              });
            },
          ),
        );
      }(),
    };
  }

  Future<void> _openDateSelector(BuildContext context) async {
    final bloc = context.read<OrdersBloc>();
    final getTodayOrders = sl<GetTodayOrders>();
    final selectedDate = await showOrderDateSelectorDialog(
      context,
      currentDate: bloc.activeDate,
      onFetchClientCount: (date) async {
        final result = await getTodayOrders(GetTodayOrdersParams(date: date));
        return result.fold((_) => null, (sheet) => sheet?.clients.length);
      },
    );
    if (selectedDate == null || !context.mounted) return;
    bloc.add(OrdersDateChanged(date: selectedDate));
  }
}
