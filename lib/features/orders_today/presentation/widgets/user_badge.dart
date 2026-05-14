import 'package:flutter/material.dart';

import '../../../../app/theme/theme_constants.dart';

/// Badge showing a connected user's name with a colored background.
class UserBadge extends StatelessWidget {
  const UserBadge({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
