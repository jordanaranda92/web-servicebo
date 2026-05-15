import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../models/client_order_summary.dart';

/// Expandable card showing a client's order summary.
///
/// Collapsed: order number, client name, total products count.
/// Expanded: one row per product with quantity, flag, refund and notes.
class OrderClientCard extends StatefulWidget {
  const OrderClientCard({
    super.key,
    required this.summary,
    required this.isExpanded,
    required this.onToggle,
  });

  final ClientOrderSummary summary;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  State<OrderClientCard> createState() => _OrderClientCardState();
}

class _OrderClientCardState extends State<OrderClientCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant OrderClientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final summary = widget.summary;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onToggle,
        child: Column(
          children: [
            // ── Collapsed header ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Order number badge
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${summary.orderNumber}',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Client name + total products stacked
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.clientName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          l10n.ordersTodayMobileProductCount(
                            _formatNum(summary.totalProducts),
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Expand/collapse icon
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more,
                      size: AppIconSizes.md,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // ── Expanded content ──
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: _buildProductList(context, summary, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    ClientOrderSummary summary,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < summary.products.length; i++)
            _buildProductRow(
              context,
              summary.products[i],
              l10n,
              colorScheme,
              textTheme,
              customColors,
              isLast: i == summary.products.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildProductRow(
    BuildContext context,
    ProductLineItem item,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    CustomColors? customColors, {
    required bool isLast,
  }) {
    return Container(
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name + quantity
          Row(
            children: [
              Expanded(
                child: Text(item.productName, style: textTheme.bodyMedium),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatNum(item.quantity),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Badges row: flag, refund, note
          if (item.flag != null || item.refund != null || item.note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (item.flag == 'reservation')
                    _buildBadge(
                      l10n.ordersTodayMobileReservation,
                      customColors?.reservation ?? colorScheme.primaryContainer,
                      colorScheme.onSurface,
                      textTheme,
                    ),
                  if (item.flag == 'compensation')
                    _buildBadge(
                      l10n.ordersTodayMobileCompensation,
                      customColors?.compensation ??
                          colorScheme.secondaryContainer,
                      colorScheme.onSurface,
                      textTheme,
                    ),
                  if (item.refund != null)
                    _buildBadge(
                      l10n.ordersTodayMobileRefund(_formatNum(item.refund!)),
                      customColors?.refund?.withValues(alpha: 0.2) ??
                          colorScheme.tertiaryContainer,
                      colorScheme.onSurface,
                      textTheme,
                    ),
                  if (item.note != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: AppIconSizes.sm,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              item.note!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    String label,
    Color backgroundColor,
    Color textColor,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.extraSmall),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _formatNum(num value) {
  if (value == value.toInt()) return value.toInt().toString();
  return value.toString();
}
