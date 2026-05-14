import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/localization/l10n/app_localizations.dart';

/// Shows a dialog for adding/editing a cell refund quantity.
/// Returns the parsed refund quantity, or `null` if cancelled or zero.
Future<num?> showOrderRefundDialog(
  BuildContext context, {
  num? existingRefund,
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(
    text: existingRefund != null && existingRefund > 0
        ? _formatNum(existingRefund)
        : '',
  );

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          l10n.ordersTodayRefundDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ordersTodayRefundDialogLabel,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value);
              },
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ordersTodayNoteDialogCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: Text(l10n.ordersTodayNoteDialogSave),
          ),
        ],
      );
    },
  ).then((result) {
    if (result == null) {
      controller.dispose();
      return null;
    }
    final parsed = num.tryParse(result.trim().replaceAll(',', '.'));
    final quantity = (parsed != null && parsed > 0) ? parsed : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return quantity;
  });
}

String _formatNum(num value) {
  if (value == value.toInt()) return value.toInt().toString();
  return value.toString();
}
