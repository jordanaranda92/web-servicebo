import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';

class OrdersEmptyState extends StatelessWidget {
  const OrdersEmptyState({super.key, required this.onCreateFile});

  final VoidCallback onCreateFile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: AppIconSizes.xl,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.ordersNoFileTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.ordersNoFileMessage,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onCreateFile,
            icon: const Icon(Icons.add),
            label: Text(l10n.ordersCreateFile),
          ),
        ],
      ),
    );
  }
}
