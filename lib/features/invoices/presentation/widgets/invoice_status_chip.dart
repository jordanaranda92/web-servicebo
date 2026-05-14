import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';

/// Chip that displays an invoice status with appropriate colors.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final (label, bgColor, fgColor) = switch (status.toLowerCase()) {
      'paid' => (
        l10n.invoiceStatusPaid,
        Colors.green.shade100,
        Colors.green.shade900,
      ),
      'pending' => (
        l10n.invoiceStatusPending,
        Colors.orange.shade100,
        Colors.orange.shade900,
      ),
      'overdue' => (
        l10n.invoiceStatusOverdue,
        Colors.red.shade100,
        Colors.red.shade900,
      ),
      'draft' => (
        l10n.invoiceStatusDraft,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
      'voided' => (
        l10n.invoiceStatusVoided,
        Colors.grey.shade200,
        Colors.grey.shade700,
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
