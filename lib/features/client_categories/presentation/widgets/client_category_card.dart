import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../../../clients/presentation/widgets/category_badge.dart';

class ClientCategoryCard extends StatelessWidget {
  const ClientCategoryCard({
    super.key,
    required this.category,
    required this.clientCount,
    required this.onEditName,
    required this.onEditColor,
    required this.onAssociateClients,
    required this.onDelete,
  });

  final ClientCategory category;
  final int clientCount;
  final VoidCallback onEditName;
  final VoidCallback onEditColor;
  final VoidCallback onAssociateClients;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

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
            // ── Name badge + menu button ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: CategoryBadge(
                    name: category.name,
                    color: category.color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: PopupMenuButton<_CategoryAction>(
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
                        case _CategoryAction.editName:
                          onEditName();
                        case _CategoryAction.editColor:
                          onEditColor();
                        case _CategoryAction.associateClients:
                          onAssociateClients();
                        case _CategoryAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _CategoryAction.editName,
                        child: _MenuRow(
                          icon: Icons.edit_outlined,
                          label: l10n.clientCategoriesEditName,
                        ),
                      ),
                      PopupMenuItem(
                        value: _CategoryAction.editColor,
                        child: _MenuRow(
                          icon: Icons.palette_outlined,
                          label: l10n.clientCategoriesEditColor,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _CategoryAction.associateClients,
                        child: _MenuRow(
                          icon: Icons.people_outline_rounded,
                          label: l10n.clientCategoriesAssociateClients,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _CategoryAction.delete,
                        child: _MenuRow(
                          icon: Icons.delete_outline_rounded,
                          label: l10n.clientCategoriesDelete,
                          isDestructive: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── Client count ──
            Row(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: AppIconSizes.sm,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$clientCount',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CategoryAction { editName, editColor, associateClients, delete }

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
