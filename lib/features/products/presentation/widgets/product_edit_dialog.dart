import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/product.dart';

/// Dialog to edit the product name.
/// Returns the new name as [String] or `null` if cancelled / unchanged.
class ProductEditDialog extends StatefulWidget {
  final Product product;

  const ProductEditDialog({super.key, required this.product});

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newName = _nameController.text.trim();
    if (newName == widget.product.name) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(newName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(
        l10n.productsEditName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.productsColumnName, style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.productsNameRequired;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.settingsSave)),
      ],
    );
  }
}
