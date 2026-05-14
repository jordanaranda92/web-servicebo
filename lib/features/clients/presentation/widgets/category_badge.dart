import 'package:flutter/material.dart';

import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/category_color_utils.dart';

class CategoryBadge extends StatelessWidget {
  final String name;
  final String? color;

  const CategoryBadge({super.key, required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final badgeBg = tryParseHex(color);
    final hasBgColor = badgeBg != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: hasBgColor ? badgeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: hasBgColor
            ? null
            : Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelSmall?.copyWith(
          color: hasBgColor
              ? contrastTextColor(badgeBg)
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
