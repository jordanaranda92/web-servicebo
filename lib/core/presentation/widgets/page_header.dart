import 'package:flutter/material.dart';

import '../../../app/theme/theme_constants.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.icon,
    this.actions,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final IconData? icon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= AppSideMenu.mobileBreakpoint) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: colorScheme.primary, size: AppIconSizes.lg),
                const SizedBox(width: AppSpacing.sm),
              ],
              titleWidget ??
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              if (actions != null) ...[const Spacer(), ...actions!],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }
}
