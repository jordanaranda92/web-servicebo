import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/category_color_utils.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_category.dart';
import '../bloc/clients_cubit.dart';

/// Dialog to edit the client name and category inline.
/// Returns the updated [Client] on success, or null on cancel.
class ClientDataEditDialog extends StatefulWidget {
  final Client client;

  const ClientDataEditDialog({super.key, required this.client});

  @override
  State<ClientDataEditDialog> createState() => _ClientDataEditDialogState();
}

class _ClientDataEditDialogState extends State<ClientDataEditDialog> {
  late final TextEditingController _nameController;
  List<ClientCategory>? _categories;
  ClientCategory? _selectedCategory;
  bool _loadingCategories = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.name);
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cubit = sl<ClientsCubit>();
    final categories = await cubit.fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories ?? [];
      _loadingCategories = false;
      _selectedCategory = _categories
          ?.where((c) => c.id == widget.client.clientCategoryId)
          .firstOrNull;
    });
  }

  bool get _hasChanges {
    final nameChanged = _nameController.text.trim() != widget.client.name;
    final categoryChanged =
        _selectedCategory?.id != widget.client.clientCategoryId;
    return nameChanged || categoryChanged;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final cubit = sl<ClientsCubit>();
    final nameChanged = name != widget.client.name;
    final categoryChanged =
        _selectedCategory?.id != widget.client.clientCategoryId;

    final success = await cubit.saveBatchChanges(
      nameChanges: nameChanged ? {widget.client.id: name} : const {},
      categoryChanges: categoryChanged
          ? {widget.client.id: _selectedCategory?.id}
          : const {},
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      final updatedClient = Client(
        id: widget.client.id,
        name: name,
        facturaDirectaUuid: widget.client.facturaDirectaUuid,
        facturaDirectaName: widget.client.facturaDirectaName,
        clientCategoryId: _selectedCategory?.id,
        categoryName: _selectedCategory?.name,
        categoryColor: _selectedCategory?.color,
        shippingMethodsByDay: widget.client.shippingMethodsByDay,
      );
      Navigator.of(context).pop(updatedClient);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(l10n.clientsEditTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.clientsColumnName,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.clientsColumnCategory,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_loadingCategories)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _buildCategoryDropdown(l10n, colorScheme, textTheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
        FilledButton(
          onPressed:
              _saving || !_hasChanges || _nameController.text.trim().isEmpty
              ? null
              : _save,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.surface,
                  ),
                )
              : Text(l10n.settingsSave),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final categories = _categories ?? [];

    return DropdownButtonFormField<String?>(
      initialValue: _selectedCategory?.id,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            l10n.clientsCategoryUnspecified,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        ...categories.map((cat) {
          final badgeBg = tryParseHex(cat.color);
          final hasBgColor = badgeBg != null;
          return DropdownMenuItem<String?>(
            value: cat.id,
            child: Row(
              children: [
                if (hasBgColor) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(cat.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: _saving
          ? null
          : (value) {
              setState(() {
                _selectedCategory = value == null
                    ? null
                    : categories.where((c) => c.id == value).firstOrNull;
              });
            },
    );
  }
}
