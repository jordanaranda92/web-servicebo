import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/client_category.dart';

/// Dialog to select a category for a client.
class CategorySelectorDialog extends StatefulWidget {
  final List<ClientCategory> categories;

  const CategorySelectorDialog({super.key, required this.categories});

  @override
  State<CategorySelectorDialog> createState() => _CategorySelectorDialogState();
}

class _CategorySelectorDialogState extends State<CategorySelectorDialog> {
  final _searchController = TextEditingController();
  late List<ClientCategory> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.categories;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filtered = widget.categories;
      } else {
        _filtered = widget.categories
            .where((c) => c.name.toLowerCase().contains(trimmed))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final border = BorderSide(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    return AlertDialog(
      title: Text(l10n.clientsSelectCategory),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l10n.clientsSelectCategorySearch,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.small),
                  topRight: Radius.circular(AppRadii.small),
                ),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.clientsColumnCategory, style: headerStyle),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadii.small),
                    bottomRight: Radius.circular(AppRadii.small),
                  ),
                  border: Border(
                    left: BorderSide(color: colorScheme.outlineVariant),
                    right: BorderSide(color: colorScheme.outlineVariant),
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.clientsSelectCategoryEmpty,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: border.color),
                        itemBuilder: (context, index) {
                          final category = _filtered[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              hoverColor: colorScheme.surfaceContainerLow,
                              onTap: () => Navigator.of(context).pop(category),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.only(
        top: AppSpacing.md,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
      ],
    );
  }
}
