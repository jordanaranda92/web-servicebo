import 'package:flutter/material.dart';

import '../../../app/localization/l10n/app_localizations.dart';
import '../../../app/theme/theme_constants.dart';

/// Reusable pagination footer with rows-per-page selector and page navigation.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalPages,
    required this.totalItems,
    required this.pageItemCount,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int currentPage;
  final int pageSize;
  final int totalPages;
  final int totalItems;
  final int pageItemCount;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final start = currentPage * pageSize + 1;
    final end = start - 1 + pageItemCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppRadii.small),
            bottomRight: Radius.circular(AppRadii.small),
          ),
          border: Border(
            left: BorderSide(color: colorScheme.outlineVariant),
            right: BorderSide(color: colorScheme.outlineVariant),
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.paginationRowsPerPage,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                isDense: true,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (v) {
                  if (v != null) onPageSizeChanged(v);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Text(
              l10n.paginationRange(start, end, totalItems),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              onPressed: currentPage > 0
                  ? () => onPageChanged(currentPage - 1)
                  : null,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: currentPage > 0
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.outlineVariant,
              ),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: currentPage < totalPages - 1
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: currentPage < totalPages - 1
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.outlineVariant,
              ),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
