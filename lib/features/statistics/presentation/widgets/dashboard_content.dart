import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/fd_counters_cubit.dart';
import '../bloc/fd_counters_state.dart';
import '../../../../core/presentation/utils/format_utils.dart';
import 'comparison_card.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvoicesCombinedCard(context),
          const SizedBox(height: AppSpacing.xl),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: l10n.dashboardComparisons,
            icon: Icons.compare_arrows_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildComparisonsGrid(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildInvoicesCombinedCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = colorScheme.primary;

    return BlocBuilder<FdCountersCubit, FdCountersState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is FdCountersLoaded &&
              current is FdCountersLoaded &&
              (previous.invoicesCount != current.invoicesCount ||
                  previous.invoicesTotal != current.invoicesTotal)),
      builder: (context, state) {
        final (count, total, subtitle, isLoading) = switch (state) {
          FdCountersInitial() ||
          FdCountersLoading() => ('', '', null as String?, true),
          FdCountersNotConfigured() => (
            '—',
            '—',
            l10n.dashboardFdNotConfigured as String?,
            false,
          ),
          FdCountersLoaded() => (
            '${state.invoicesCount}',
            formatCurrencyEur(state.invoicesTotal),
            null as String?,
            false,
          ),
          FdCountersError() => (
            '—',
            '—',
            l10n.dashboardFdError as String?,
            false,
          ),
        };

        Widget content = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.08),
                accent.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        Icons.receipt_rounded,
                        size: AppIconSizes.md,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.menuInvoices,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _InvoiceRow(
                  label: l10n.dashboardInvoicesLabel,
                  value: isLoading ? '000' : count,
                  icon: Icons.receipt_outlined,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: AppSpacing.sm),
                _InvoiceRow(
                  label: l10n.dashboardInvoicesTotalLabel,
                  value: isLoading ? '000,00 €' : total,
                  icon: Icons.euro_outlined,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        if (isLoading) {
          content = Skeletonizer(enabled: true, child: content);
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(AppRoutes.invoices),
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: content,
          ),
        );
      },
    );
  }

  String _fmtDay(DateTime d) =>
      l10n.dashboardDateFormat(d.day, localizedMonths(l10n)[d.month - 1]);

  String _fmtRange(DateTime start, DateTime end) {
    final months = localizedMonths(l10n);
    if (start.month == end.month) {
      return l10n.dashboardDateRangeFormat(
        start.day,
        end.day,
        months[start.month - 1],
      );
    }
    return '${_fmtDay(start)} – ${_fmtDay(end)}';
  }

  Widget _buildComparisonsGrid(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sameWeekdayLastWeek = today.subtract(const Duration(days: 7));

    final mondayThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final mondayLastWeek = mondayThisWeek.subtract(const Duration(days: 7));
    final equivalentDayLastWeek = mondayLastWeek.add(
      Duration(days: today.weekday - 1),
    );

    final subVsYesterday = '${_fmtDay(today)} vs. ${_fmtDay(yesterday)}';
    final subVsSameWeekday =
        '${_fmtDay(today)} vs. ${_fmtDay(sameWeekdayLastWeek)}';
    final subVsLastWeek =
        '${_fmtRange(mondayThisWeek, today)} vs. ${_fmtRange(mondayLastWeek, equivalentDayLastWeek)}';

    return BlocBuilder<FdCountersCubit, FdCountersState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (previous is FdCountersLoaded &&
              current is FdCountersLoaded &&
              (previous.vsYesterday != current.vsYesterday ||
                  previous.vsSameWeekday != current.vsSameWeekday ||
                  previous.vsLastWeek != current.vsLastWeek)),
      builder: (context, fdState) {
        final fdLoaded = fdState is FdCountersLoaded ? fdState : null;
        final fdLoading =
            fdState is FdCountersLoading || fdState is FdCountersInitial;

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const gap = AppSpacing.md;

            // Calculate how many cards fit per row (min 280px each)
            final cardsPerRow = ((availableWidth + gap) / (280.0 + gap))
                .floor()
                .clamp(1, 3);
            final cardWidth = cardsPerRow > 1
                ? (availableWidth - (cardsPerRow - 1) * gap) / cardsPerRow
                : availableWidth;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: ComparisonCard(
                    title: l10n.dashboardVsYesterday,
                    subtitle: subVsYesterday,
                    hasData: fdLoaded?.vsYesterday != null,
                    invoicesDiff: fdLoaded?.vsYesterday?.invoicesDiff,
                    invoicesTotalDiff: fdLoaded?.vsYesterday?.invoicesTotalDiff,
                    isLoadingFd: fdLoading,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ComparisonCard(
                    title: l10n.dashboardVsSameWeekday,
                    subtitle: subVsSameWeekday,
                    hasData: fdLoaded?.vsSameWeekday != null,
                    invoicesDiff: fdLoaded?.vsSameWeekday?.invoicesDiff,
                    invoicesTotalDiff:
                        fdLoaded?.vsSameWeekday?.invoicesTotalDiff,
                    isLoadingFd: fdLoading,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ComparisonCard(
                    title: l10n.dashboardVsLastWeek,
                    subtitle: subVsLastWeek,
                    hasData: fdLoaded?.vsLastWeek != null,
                    invoicesDiff: fdLoaded?.vsLastWeek?.invoicesDiff,
                    invoicesTotalDiff: fdLoaded?.vsLastWeek?.invoicesTotalDiff,
                    isLoadingFd: fdLoading,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String value;
  final IconData icon;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.extraSmall),
          ),
          child: Text(
            value,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: AppIconSizes.md, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
