import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../domain/entities/fd_product.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.fdProduct,
    required this.onEditName,
    required this.onLink,
    required this.onUnlink,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Product product;
  final FdProduct? fdProduct;
  final VoidCallback onEditName;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final hasLink = product.facturaDirectaUuid.isNotEmpty;
    final successColor =
        Theme.of(context).extension<CustomColors>()?.success ?? Colors.green;

    return Card(
      elevation: AppElevation.low,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: product name + menu button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildMenuButton(colorScheme, l10n, hasLink),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // FD product info
            if (hasLink && fdProduct != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: successColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      fdProduct!.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (fdProduct!.salesPrice != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${fdProduct!.salesPrice!.toStringAsFixed(2)} ${fdProduct!.currency ?? ''}'
                      .trim(),
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else
              Row(
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    size: 14,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.productsNoFdLinked,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            // Active/Inactive badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: product.isActive
                    ? successColor.withValues(alpha: 0.15)
                    : colorScheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Text(
                product.isActive
                    ? l10n.productsColumnActive
                    : l10n.productsColumnInactive,
                style: textTheme.labelSmall?.copyWith(
                  color: product.isActive ? successColor : colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    ColorScheme colorScheme,
    AppLocalizations l10n,
    bool hasLink,
  ) {
    return SizedBox(
      height: 32,
      width: 32,
      child: PopupMenuButton<_ProductAction>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        onSelected: (action) {
          switch (action) {
            case _ProductAction.editName:
              onEditName();
            case _ProductAction.linkFd:
              onLink();
            case _ProductAction.modifyFd:
              onLink();
            case _ProductAction.unlinkFd:
              onUnlink();
            case _ProductAction.toggleActive:
              onToggleActive();
            case _ProductAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _ProductAction.editName,
            child: _MenuRow(
              icon: Icons.edit_outlined,
              label: l10n.productsEditName,
            ),
          ),
          if (hasLink) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _ProductAction.modifyFd,
              child: _MenuRow(
                icon: Icons.sync_alt_rounded,
                label: l10n.productsModifyFdProduct,
              ),
            ),
            PopupMenuItem(
              value: _ProductAction.unlinkFd,
              child: _MenuRow(
                icon: Icons.link_off,
                label: l10n.productsUnlinkFdProduct,
                isDestructive: true,
              ),
            ),
            const PopupMenuDivider(),
          ] else ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _ProductAction.linkFd,
              child: _MenuRow(
                icon: Icons.link,
                label: l10n.productsSelectFdProduct,
              ),
            ),
            const PopupMenuDivider(),
          ],
          PopupMenuItem(
            value: _ProductAction.toggleActive,
            child: _MenuRow(
              icon: product.isActive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              label: product.isActive
                  ? l10n.productsDeactivate
                  : l10n.productsActivate,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _ProductAction.delete,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l10n.productsDelete,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProductAction {
  editName,
  linkFd,
  modifyFd,
  unlinkFd,
  toggleActive,
  delete,
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
