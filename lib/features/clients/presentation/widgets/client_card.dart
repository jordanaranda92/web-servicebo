import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/client.dart';
import 'category_badge.dart';

class ClientCard extends StatelessWidget {
  const ClientCard({
    super.key,
    required this.client,
    this.fiscalId,
    required this.onTap,
  });

  final Client client;
  final String? fiscalId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categoryName = client.categoryName;
    final hasCategory = categoryName != null && categoryName.isNotEmpty;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (hasCategory) ...[
                const SizedBox(height: AppSpacing.xs),
                CategoryBadge(name: categoryName, color: client.categoryColor),
              ] else ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppLocalizations.of(context)!.clientsCategoryUnspecified,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                fiscalId ?? '—',
                style: textTheme.bodySmall?.copyWith(
                  color: fiscalId != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (client.facturaDirectaName.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  client.facturaDirectaName,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
