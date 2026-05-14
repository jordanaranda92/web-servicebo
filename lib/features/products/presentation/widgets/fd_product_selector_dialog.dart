import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/fd_product.dart';

/// Dialog to select a FacturaDirecta product for linking.
class FdProductSelectorDialog extends StatefulWidget {
  final List<FdProduct> fdProducts;
  final String productName;

  const FdProductSelectorDialog({
    super.key,
    required this.fdProducts,
    required this.productName,
  });

  @override
  State<FdProductSelectorDialog> createState() =>
      _FdProductSelectorDialogState();
}

class _FdProductSelectorDialogState extends State<FdProductSelectorDialog> {
  final _searchController = TextEditingController();
  late List<FdProduct> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.fdProducts;
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
        _filtered = widget.fdProducts;
      } else {
        _filtered = widget.fdProducts
            .where((p) => p.name.toLowerCase().contains(trimmed))
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
    final isMobile =
        MediaQuery.sizeOf(context).width <= AppSideMenu.mobileBreakpoint;

    return AlertDialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xl,
            )
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.productsSelectFdTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.productsLinkDialogSubtitle(widget.productName),
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
      content: SizedBox(
        width: isMobile ? double.maxFinite : 500,
        height: 500,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l10n.productsSelectFdSearch,
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
            if (!isMobile)
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
                      child: Text(l10n.productsColumnName, style: headerStyle),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        l10n.productsColumnPrice,
                        style: headerStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMobile ? AppRadii.small : 0),
                    topRight: Radius.circular(isMobile ? AppRadii.small : 0),
                    bottomLeft: const Radius.circular(AppRadii.small),
                    bottomRight: const Radius.circular(AppRadii.small),
                  ),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.productsSelectFdEmpty,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final product = _filtered[index];
                          final priceText = product.salesPrice != null
                              ? '${product.salesPrice!.toStringAsFixed(2)} ${product.currency ?? ''}'
                                    .trim()
                              : '';
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              hoverColor: colorScheme.surfaceContainerLow,
                              onTap: () => Navigator.of(context).pop(product),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                child: isMobile
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: textTheme.bodyMedium,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (priceText.isNotEmpty) ...[
                                            const SizedBox(
                                              height: AppSpacing.xxs,
                                            ),
                                            Text(
                                              priceText,
                                              style: textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              priceText,
                                              textAlign: TextAlign.right,
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
      actionsPadding: const EdgeInsets.only(
        top: AppSpacing.md,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.primary),
          ),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
