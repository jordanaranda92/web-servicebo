import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/shipping_method.dart';

class ShippingMethodCard extends StatelessWidget {
  const ShippingMethodCard({
    super.key,
    required this.method,
    required this.onEditName,
    required this.onEditPhone,
    required this.onAssociateClients,
    required this.onDelete,
  });

  final ShippingMethod method;
  final VoidCallback onEditName;
  final VoidCallback onEditPhone;
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    method.phone.isNotEmpty ? method.phone : '—',
                    style: textTheme.bodySmall?.copyWith(
                      color: method.phone.isNotEmpty
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: 32,
              width: 32,
              child: PopupMenuButton<_ShippingAction>(
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
                    case _ShippingAction.editName:
                      onEditName();
                    case _ShippingAction.editPhone:
                      onEditPhone();
                    case _ShippingAction.associateClients:
                      onAssociateClients();
                    case _ShippingAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ShippingAction.editName,
                    child: _MenuRow(
                      icon: Icons.edit_outlined,
                      label: l10n.shippingMethodsEditName,
                    ),
                  ),
                  PopupMenuItem(
                    value: _ShippingAction.editPhone,
                    child: _MenuRow(
                      icon: Icons.phone_outlined,
                      label: l10n.shippingMethodsEditPhone,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _ShippingAction.associateClients,
                    child: _MenuRow(
                      icon: Icons.people_outline_rounded,
                      label: l10n.shippingMethodsAssociateClients,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _ShippingAction.delete,
                    child: _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.shippingMethodsDelete,
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShippingAction { editName, editPhone, associateClients, delete }

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
