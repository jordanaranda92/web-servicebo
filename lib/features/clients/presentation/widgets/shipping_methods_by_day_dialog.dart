import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/day_utils.dart';
import '../../../shipping_methods/domain/entities/shipping_method.dart';

/// Dialog to assign a shipping method per day of the week for a client.
///
/// Returns a `Map<String, String?>` where keys are day codes
/// (`monday`–`sunday`) and values are shipping method IDs or `null`.
class ShippingMethodsByDayDialog extends StatefulWidget {
  final List<ShippingMethod> shippingMethods;
  final Map<String, String> currentAssignments;

  const ShippingMethodsByDayDialog({
    super.key,
    required this.shippingMethods,
    required this.currentAssignments,
  });

  @override
  State<ShippingMethodsByDayDialog> createState() =>
      _ShippingMethodsByDayDialogState();
}

class _ShippingMethodsByDayDialogState
    extends State<ShippingMethodsByDayDialog> {
  late final Map<String, String?> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = {
      for (final day in dayOrder) day: widget.currentAssignments[day],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Build method lookup (filter out invalid IDs)
    final methodMap = {for (final m in widget.shippingMethods) m.id: m};

    return AlertDialog(
      title: Text(
        l10n.clientsShippingMethodsTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.clientsShippingMethodsSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final dayCode in dayOrder) ...[
              _buildDayRow(dayCode, l10n, colorScheme, textTheme, methodMap),
              if (dayCode != dayOrder.last)
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_assignments),
          child: Text(l10n.settingsSave),
        ),
      ],
    );
  }

  Widget _buildDayRow(
    String dayCode,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Map<String, ShippingMethod> methodMap,
  ) {
    final currentId = _assignments[dayCode];
    // Ignore orphaned IDs
    final validId = currentId != null && methodMap.containsKey(currentId)
        ? currentId
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              localizedDay(dayCode, l10n),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: validId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l10n.clientsShippingMethodNone,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                ...widget.shippingMethods.map(
                  (method) => DropdownMenuItem<String?>(
                    value: method.id,
                    child: Text(method.name, style: textTheme.bodyMedium),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _assignments[dayCode] = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
