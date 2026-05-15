import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/format_utils.dart';

enum TrendDirection { up, down, neutral }

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({
    super.key,
    required this.title,
    this.subtitle,
    this.invoicesDiff,
    this.invoicesTotalDiff,
    this.hasData = true,
    this.isLoadingFd = false,
  });

  final String title;
  final String? subtitle;
  final int? invoicesDiff;
  final double? invoicesTotalDiff;
  final bool hasData;
  final bool isLoadingFd;

  TrendDirection _trendFor(num? diff) {
    if (diff == null || diff == 0) return TrendDirection.neutral;
    return diff > 0 ? TrendDirection.up : TrendDirection.down;
  }

  TrendDirection get _overallTrend {
    if (!hasData && !isLoadingFd) {
      return TrendDirection.neutral;
    }
    if (invoicesTotalDiff != null && invoicesTotalDiff != 0) {
      return _trendFor(invoicesTotalDiff);
    }
    return TrendDirection.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final customColors = Theme.of(context).extension<CustomColors>();

    final accentColor = switch (_overallTrend) {
      TrendDirection.up => customColors?.success ?? Colors.green,
      TrendDirection.down => colorScheme.error,
      TrendDirection.neutral => colorScheme.onSurfaceVariant,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: BorderSide(color: accentColor.withValues(alpha: 0.25)),
      ),
      color: accentColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _buildTrendIcon(accentColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: Text(
                            subtitle!,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!hasData && !isLoadingFd)
              Text(
                l10n.dashboardNoData,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Skeletonizer(
                enabled: isLoadingFd,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMetricRow(
                      context,
                      Icons.receipt_outlined,
                      isLoadingFd ? '+00' : _formatIntDiff(invoicesDiff),
                      l10n.dashboardInvoicesLabel,
                      isLoadingFd
                          ? TrendDirection.neutral
                          : _trendFor(invoicesDiff),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildMetricRow(
                      context,
                      Icons.euro_outlined,
                      isLoadingFd
                          ? '+000,00 €'
                          : _formatCurrencyDiff(invoicesTotalDiff),
                      l10n.dashboardInvoicesTotalLabel,
                      isLoadingFd
                          ? TrendDirection.neutral
                          : _trendFor(invoicesTotalDiff),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIcon(Color color) {
    final icon = switch (_overallTrend) {
      TrendDirection.up => Icons.trending_up_rounded,
      TrendDirection.down => Icons.trending_down_rounded,
      TrendDirection.neutral => Icons.trending_flat_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    TrendDirection trend,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final color = switch (trend) {
      TrendDirection.up =>
        Theme.of(context).extension<CustomColors>()?.success ?? Colors.green,
      TrendDirection.down => colorScheme.error,
      TrendDirection.neutral => colorScheme.onSurfaceVariant,
    };

    final badgeBg = switch (trend) {
      TrendDirection.up =>
        (Theme.of(context).extension<CustomColors>()?.success ?? Colors.green)
            .withValues(alpha: 0.1),
      TrendDirection.down => colorScheme.error.withValues(alpha: 0.1),
      TrendDirection.neutral => colorScheme.surfaceContainerHighest,
    };

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
            color: badgeBg,
            borderRadius: BorderRadius.circular(AppRadii.extraSmall),
          ),
          child: Text(
            value,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
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

  String _formatIntDiff(int? diff) {
    if (diff == null) return '0';
    final sign = diff > 0 ? '+' : '';
    return '$sign$diff';
  }

  String _formatCurrencyDiff(double? diff) {
    if (diff == null) return '0 €';
    final sign = diff > 0 ? '+' : (diff < 0 ? '-' : '');
    return '$sign${formatCurrencyEur(diff)}';
  }
}
