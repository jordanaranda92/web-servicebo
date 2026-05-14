import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';

/// Shows a dialog for adding/editing a cell note.
/// Returns the note text, or `null` if cancelled.
Future<String?> showOrderNoteDialog(
  BuildContext context, {
  String? existingNote,
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: existingNote ?? '');

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          l10n.ordersTodayNoteDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ordersTodayNoteDialogHint,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLength: 100,
              autofocus: true,
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
    final note = result.trim().isEmpty ? null : result.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return note;
  });
}
