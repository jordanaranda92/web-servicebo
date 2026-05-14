import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';

/// Toolbar for the orders table with delete/reset actions.
class OrdersTableToolbar extends StatelessWidget {
  const OrdersTableToolbar({
    super.key,
    required this.selectedColumnCount,
    required this.selectedRowCount,
    required this.onDelete,
    required this.onResetOrders,
  });

  final int selectedColumnCount;
  final int selectedRowCount;
  final VoidCallback? onDelete;
  final VoidCallback? onResetOrders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: (selectedColumnCount > 0 || selectedRowCount > 0)
                ? onDelete
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            label: Text(l10n.ordersTodayRemoveFromTable),
          ),
          const Spacer(),
          if (selectedColumnCount > 0) ...[
            OutlinedButton.icon(
              onPressed: onResetOrders,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(l10n.ordersTodayResetOrders),
            ),
          ],
        ],
      ),
    );
  }
}
