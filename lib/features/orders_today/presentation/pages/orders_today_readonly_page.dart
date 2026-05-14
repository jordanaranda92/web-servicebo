import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/orders_today_bloc.dart';
import '../bloc/orders_today_event.dart';
import '../bloc/orders_today_state.dart';
import '../widgets/orders_table.dart';
import '../widgets/readonly_footer.dart';

/// Read-only view of today's orders, intended for large monitors
/// in the packaging area.
///
/// - No side menu (`SideMenuShell`).
/// - No editing capabilities.
/// - Auto-updates via Firestore listeners.
/// - Shows last modification timestamp with a live indicator.
class OrdersTodayReadonlyPage extends StatefulWidget {
  const OrdersTodayReadonlyPage({super.key});

  @override
  State<OrdersTodayReadonlyPage> createState() =>
      _OrdersTodayReadonlyPageState();
}

class _OrdersTodayReadonlyPageState extends State<OrdersTodayReadonlyPage> {
  late final OrdersTodayBloc _bloc;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _bloc = sl<OrdersTodayBloc>()
      ..add(const OrdersTodayLoadRequested(createIfMissing: false));
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
      body: BlocProvider<OrdersTodayBloc>.value(
        value: _bloc,
        child: BlocConsumer<OrdersTodayBloc, OrdersTodayState>(
          listenWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            // Track connection: consider connected while receiving Loaded states
            if (state is OrdersTodayLoaded) {
              if (!_isConnected) setState(() => _isConnected = true);
            } else if (state is OrdersTodayError) {
              if (_isConnected) setState(() => _isConnected = false);
            }
          },
          buildWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType ||
              previous != current,
          builder: (context, state) {
            return switch (state) {
              OrdersTodayInitial() || OrdersTodayLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrdersTodayCreating() || OrdersTodayNoFile() => Center(
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
                      l10n.ordersTodayNoOrdersToday,
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              OrdersTodayError() => Center(
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
                      l10n.ordersTodayNoOrdersToday,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => _bloc.add(
                        const OrdersTodayLoadRequested(createIfMissing: false),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.ordersTodayRetry),
                    ),
                  ],
                ),
              ),
              OrdersTodayLoaded(:final orderSheet) => OrdersTable(
                orderSheet: orderSheet,
                readOnly: true,
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
}
