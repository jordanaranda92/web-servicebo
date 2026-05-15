import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/app_date_formats.dart';
import '../bloc/orders_today_bloc.dart';
import '../bloc/orders_today_event.dart';
import '../bloc/orders_today_state.dart';
import '../models/client_order_summary.dart';
import 'order_client_card.dart';
import 'orders_empty_state.dart';
import 'orders_error_state.dart';
import 'orders_preparing_state.dart';

/// Read-only mobile view for today's orders.
///
/// Listens to [OrdersTodayBloc] and renders a scrollable list of
/// [OrderClientCard] widgets — one per client with relevant order data.
class OrdersTodayMobileView extends StatefulWidget {
  const OrdersTodayMobileView({super.key});

  @override
  State<OrdersTodayMobileView> createState() => _OrdersTodayMobileViewState();
}

class _OrdersTodayMobileViewState extends State<OrdersTodayMobileView> {
  /// Index of the currently expanded card, or -1 if none.
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Content ──
        Expanded(
          child: BlocBuilder<OrdersTodayBloc, OrdersTodayState>(
            buildWhen: (previous, current) =>
                previous.runtimeType != current.runtimeType ||
                previous != current,
            builder: (context, state) {
              return switch (state) {
                OrdersTodayInitial() || OrdersTodayLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                OrdersTodayCreating() => const OrdersPreparingState(),
                OrdersTodayNoFile() => OrdersEmptyState(
                  onCreateFile: () => context.read<OrdersTodayBloc>().add(
                    const OrdersTodayCreateFileRequested(),
                  ),
                ),
                OrdersTodayError(:final errorType) => OrdersErrorState(
                  errorType: errorType,
                  onRetry: () => context.read<OrdersTodayBloc>().add(
                    const OrdersTodayRefreshRequested(),
                  ),
                ),
                OrdersTodayLoaded(:final orderSheet) => () {
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
                              l10n.ordersTodayMobileNoOrders,
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
            },
          ),
        ),
      ],
    );
  }
}

/// Mobile header showing the date, similar to the desktop header but compact.
class _MobileHeader extends StatelessWidget {
  // Cached once — the day doesn't change while the widget lives.
  static String? _cachedDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    _cachedDate ??= () {
      final now = DateTime.now();
      final formatted = AppDateFormats.dateWithDay().format(now);
      return formatted[0].toUpperCase() + formatted.substring(1);
    }();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.ordersTodayHeaderLabel,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            _cachedDate!,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
