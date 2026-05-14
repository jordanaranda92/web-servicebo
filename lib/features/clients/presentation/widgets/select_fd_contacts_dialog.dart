import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/fd_new_contact.dart';

class SelectFdContactsDialog extends StatefulWidget {
  final List<FdNewContact> contacts;

  const SelectFdContactsDialog({super.key, required this.contacts});

  @override
  State<SelectFdContactsDialog> createState() => _SelectFdContactsDialogState();
}

class _SelectFdContactsDialogState extends State<SelectFdContactsDialog> {
  final _selected = <int>{};

  bool get _allSelected => _selected.length == widget.contacts.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(List.generate(widget.contacts.length, (i) => i));
      }
    });
  }

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: Text(l10n.clientsAddFromFdDialogTitle),
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: 0,
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    l10n.clientsAddFromFdSelectedCount(
                      _selected.length,
                      widget.contacts.length,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _toggleAll,
                    child: Text(
                      _allSelected
                          ? l10n.clientsAddFromFdDeselectAll
                          : l10n.clientsAddFromFdSelectAll,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.contacts.length,
                itemBuilder: (context, index) {
                  final contact = widget.contacts[index];
                  final isSelected = _selected.contains(index);
                  final name = contact.displayName.isNotEmpty
                      ? contact.displayName
                      : l10n.clientsAddFromFdNoName;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggle(index),
                    title: Text(
                      name,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: contact.fiscalId.isNotEmpty
                        ? Text(
                            contact.fiscalId,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<List<FdNewContact>>(null),
          child: Text(l10n.clientsAddFromFdCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  final selectedContacts = _selected
                      .map((i) => widget.contacts[i])
                      .toList();
                  Navigator.of(
                    context,
                  ).pop<List<FdNewContact>>(selectedContacts);
                },
          child: Text(l10n.clientsAddFromFdConfirm(_selected.length)),
        ),
      ],
    );
  }
}
