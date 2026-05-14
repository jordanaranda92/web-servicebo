import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';

/// Chip that displays an invoice status with appropriate colors.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<CustomColors>();
    final l10n = AppLocalizations.of(context)!;
    final successColor = customColors?.success ?? Colors.green;
    final pendingColor = Colors.orange;
    final dangerColor = customColors?.danger ?? Colors.red;
    final (label, bgColor, fgColor) = switch (status.toLowerCase()) {
      'paid' => (
        l10n.invoiceStatusPaid,
        successColor.withValues(alpha: 0.15),
        successColor,
      ),
      'pending' => (
        l10n.invoiceStatusPending,
        pendingColor.withValues(alpha: 0.15),
        pendingColor,
      ),
      'overdue' => (
        l10n.invoiceStatusOverdue,
        dangerColor.withValues(alpha: 0.15),
        dangerColor,
      ),
      'draft' => (
        l10n.invoiceStatusDraft,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
      'voided' => (
        l10n.invoiceStatusVoided,
        colorScheme.outlineVariant.withValues(alpha: 0.3),
        colorScheme.onSurfaceVariant,
      ),
      'overpaid' => (
        l10n.invoiceStatusOverpaid,
        Colors.purple.shade100,
        Colors.purple.shade900,
      ),
      _ => (
        status,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
