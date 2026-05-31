import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/usecases/get_today_orders.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../widgets/order_date_selector_dialog.dart';
import '../widgets/orders_table.dart';
import '../widgets/readonly_footer.dart';

/// Read-only view of today's orders, intended for large monitors
/// in the packaging area.
///
/// - No side menu (`SideMenuShell`).
/// - No editing capabilities.
/// - Auto-updates via Firestore listeners.
/// - Shows last modification timestamp with a live indicator.
class OrdersReadonlyPage extends StatefulWidget {
  const OrdersReadonlyPage({super.key});

  @override
  State<OrdersReadonlyPage> createState() => _OrdersReadonlyPageState();
}

class _OrdersReadonlyPageState extends State<OrdersReadonlyPage> {
  late final OrdersBloc _bloc;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _bloc = sl<OrdersBloc>()
      ..add(const OrdersLoadRequested(createIfMissing: false));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: l10n.ordersDateSelectorTitle,
            onPressed: () => _openDateSelector(context),
          ),
        ],
      ),
      body: BlocProvider<OrdersBloc>.value(
        value: _bloc,
        child: BlocConsumer<OrdersBloc, OrdersState>(
          listenWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            // Track connection: consider connected while receiving Loaded states
            if (state is OrdersLoaded) {
              if (!_isConnected) setState(() => _isConnected = true);
            } else if (state is OrdersError) {
              if (_isConnected) setState(() => _isConnected = false);
            }
          },
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              previous != current,
          builder: (context, state) {
            return switch (state) {
              OrdersInitial() || OrdersLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrdersCreating() || OrdersNoFile() => Center(
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
                      l10n.ordersNoOrdersToday,
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              OrdersError() => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AppIconSizes.xl,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.ordersNoOrdersToday,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => _bloc.add(
                        const OrdersLoadRequested(createIfMissing: false),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.ordersRetry),
                    ),
                  ],
                ),
              ),
              OrdersLoaded(:final orderSheet, :final activeDate) => OrdersTable(
                orderSheet: orderSheet,
                selectedDate: activeDate,
                readOnly: true,
                onDateSelectorTap: () => _openDateSelector(context),
                footerTrailing: ReadonlyFooter(
                  lastModifiedAt: orderSheet.lastModifiedAt,
                  isConnected: _isConnected,
                ),
              ),
            };
          },
        ),
      ),
    );
  }

  Future<void> _openDateSelector(BuildContext context) async {
    final getTodayOrders = sl<GetTodayOrders>();
    final selectedDate = await showOrderDateSelectorDialog(
      context,
      currentDate: _bloc.activeDate,
      onFetchClientCount: (date) async {
        final result = await getTodayOrders(GetTodayOrdersParams(date: date));
        return result.fold((_) => null, (sheet) => sheet?.clients.length);
      },
    );
    if (selectedDate == null || !context.mounted) return;
    _bloc.add(OrdersDateChanged(date: selectedDate));
  }
}
