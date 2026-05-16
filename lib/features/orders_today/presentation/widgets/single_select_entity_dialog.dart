import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';

/// A dialog that shows a searchable list for single-selection with a confirm
/// button. Returns the selected ID when confirmed, or `null` if cancelled.
class SingleSelectEntityDialog extends StatefulWidget {
  const SingleSelectEntityDialog({
    super.key,
    required this.title,
    required this.items,
    required this.emptyIcon,
    required this.confirmLabel,
  });

  final String title;
  final List<({String id, String name})> items;
  final IconData emptyIcon;
  final String confirmLabel;

  @override
  State<SingleSelectEntityDialog> createState() =>
      _SingleSelectEntityDialogState();
}

class _SingleSelectEntityDialogState extends State<SingleSelectEntityDialog> {
  String? _selectedId;
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({String id, String name})> get _filteredItems {
    if (_filter.isEmpty) return widget.items;
    final lower = _filter.toLowerCase();
    return widget.items
        .where((e) => e.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredItems;
    final borderColor = colorScheme.outlineVariant;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: widget.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.emptyIcon,
                      size: AppIconSizes.xl,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.ordersTodayAddDialogEmpty,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // ── Search field ──
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _filter = v),
                      decoration: InputDecoration(
                        hintText: l10n.ordersTodayAddDialogSearch,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filter = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.small),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.small),
                          borderSide: BorderSide(color: borderColor),
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
                  // ── Table header ──
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadii.small),
                        topRight: Radius.circular(AppRadii.small),
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 32),
                        Expanded(
                          child: Text(
                            l10n.ordersTodayAddDialogColumnName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Table body ──
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(AppRadii.small),
                          bottomRight: Radius.circular(AppRadii.small),
                        ),
                        border: Border(
                          left: BorderSide(color: borderColor),
                          right: BorderSide(color: borderColor),
                          bottom: BorderSide(color: borderColor),
                        ),
                      ),
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                l10n.ordersTodayAddDialogNoResults,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: borderColor.withValues(alpha: 0.5),
                              ),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final isSelected = _selectedId == item.id;
                                return Material(
                                  color: isSelected
                                      ? colorScheme.primaryContainer
                                      : Colors.transparent,
                                  child: InkWell(
                                    hoverColor: colorScheme.surfaceContainerLow,
                                    onTap: () {
                                      setState(() {
                                        _selectedId = item.id;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            size: 24,
                                            color: isSelected
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
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
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop<String>(null),
          child: Text(l10n.settingsCancel),
        ),
        if (widget.items.isNotEmpty)
          FilledButton(
            onPressed: _selectedId != null
                ? () => Navigator.of(context).pop(_selectedId)
                : null,
            child: Text(widget.confirmLabel),
          ),
      ],
    );
  }
}
