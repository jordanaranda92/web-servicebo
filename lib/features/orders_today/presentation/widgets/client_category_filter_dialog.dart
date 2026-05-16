import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/category_color_utils.dart';
import '../../../clients/domain/entities/client_category.dart';

/// Synthetic ID used to represent clients with no category assigned.
const noCategoryId = '__no_category__';

class ClientCategoryFilterDialog extends StatefulWidget {
  const ClientCategoryFilterDialog({
    super.key,
    required this.categories,
    required this.selectedIds,
  });

  final List<ClientCategory> categories;
  final Set<String> selectedIds;

  @override
  State<ClientCategoryFilterDialog> createState() =>
      _ClientCategoryFilterDialogState();
}

class _ClientCategoryFilterDialogState
    extends State<ClientCategoryFilterDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedIds};
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..addAll(widget.categories.map((c) => c.id))
        ..add(noCategoryId);
    });
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  bool get _isAllSelected {
    final allIds = widget.categories.map((c) => c.id).toSet()
      ..add(noCategoryId);
    return allIds.every(_selected.contains);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasCategories = widget.categories.isNotEmpty;

    return AlertDialog(
      title: Text(l10n.ordersTodayFilterClientsDialogTitle),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 340,
        child: hasCategories
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Select all
                            CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _isAllSelected,
                              onChanged: (_) {
                                if (_isAllSelected) {
                                  _clearAll();
                                } else {
                                  _selectAll();
                                }
                              },
                              title: Text(
                                l10n.ordersTodayFilterSelectAll,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            // Real categories
                            for (final category in widget.categories)
                              CheckboxListTile(
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _selected.contains(category.id),
                                onChanged: (_) => _toggle(category.id),
                                title: Text(category.name),
                                secondary: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        tryParseHex(category.color) ??
                                        colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            const Divider(height: 1),
                            // "No category" option
                            CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _selected.contains(noCategoryId),
                              onChanged: (_) => _toggle(noCategoryId),
                              title: Text(
                                l10n.ordersTodayFilterNoCategoryLabel,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.ordersTodayFilterNoCategories,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.primary),
          ),
          child: Text(l10n.ordersTodayFilterCancel),
        ),
        if (hasCategories)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text(l10n.ordersTodayFilterApply),
          ),
      ],
    );
  }
}
