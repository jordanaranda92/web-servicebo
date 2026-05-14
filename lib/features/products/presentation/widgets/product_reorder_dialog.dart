import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/product.dart';

/// Dialog that allows the user to reorder products via drag & drop.
///
/// Receives a snapshot of [products] sorted by current order. Returns a
/// `Map<String, int>` with `{productId: newOrder}` for every product whose
/// order changed, or `null` if the user cancelled or nothing changed.
class ProductReorderDialog extends StatefulWidget {
  final List<Product> products;

  const ProductReorderDialog({super.key, required this.products});

  @override
  State<ProductReorderDialog> createState() => _ProductReorderDialogState();
}

class _ProductReorderDialogState extends State<ProductReorderDialog> {
  late final List<Product> _items;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _items = List<Product>.from(widget.products);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Map<String, int>? _computeChanges() {
    final changes = <String, int>{};
    for (var i = 0; i < _items.length; i++) {
      final newOrder = i + 1;
      final product = _items[i];
      if (product.order != newOrder) {
        changes[product.id] = newOrder;
      }
    }
    return changes.isEmpty ? null : changes;
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

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.productsReorderTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.productsReorderSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            // Table header
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
                  const SizedBox(width: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(l10n.productsColumnName, style: headerStyle),
                  ),
                ],
              ),
            ),
            // Scrollable body
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
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadii.small),
                    bottomRight: Radius.circular(AppRadii.small),
                  ),
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: WidgetStatePropertyAll(colorScheme.primary),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        itemCount: _items.length,
                        onReorder: _onReorder,
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(
                                AppRadii.small,
                              ),
                              child: child,
                            ),
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final product = _items[index];
                          final isInactive = !product.isActive;

                          return Material(
                            key: ValueKey(product.id),
                            color: Colors.transparent,
                            child: Opacity(
                              opacity: isInactive ? 0.5 : 1.0,
                              child: ReorderableDragStartListener(
                                index: index,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm + 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.drag_handle_rounded,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
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
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            final changes = _computeChanges();
            Navigator.of(context).pop(changes);
          },
          child: Text(l10n.settingsSave),
        ),
      ],
    );
  }
}
