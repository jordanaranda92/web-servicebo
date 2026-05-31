import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.onItemSelected,
    required this.onToggleExpanded,
    this.showToggleButton = true,
    this.isAdmin = false,
  });

  final int selectedIndex;
  final bool isExpanded;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleExpanded;
  final bool showToggleButton;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final items = [
      _MenuItemData(
        icon: Icons.receipt_long_rounded,
        label: l10n.menuOrders,
        hasDividerAfter: true,
      ),
      _MenuItemData(icon: Icons.people_rounded, label: l10n.menuClients),
      _MenuItemData(
        icon: Icons.category_rounded,
        label: l10n.menuClientCategories,
      ),
      _MenuItemData(
        icon: Icons.local_shipping_rounded,
        label: l10n.menuShippingMethods,
      ),
      _MenuItemData(
        icon: Icons.inventory_2_rounded,
        label: l10n.menuProducts,
        hasDividerAfter: true,
      ),
      _MenuItemData(
        icon: Icons.receipt_rounded,
        label: l10n.menuInvoices,
        hasDividerAfter: true,
      ),
      if (isAdmin)
        _MenuItemData(
          icon: Icons.bar_chart_rounded,
          label: l10n.menuStatistics,
          hasDividerAfter: true,
        ),
      _MenuItemData(icon: Icons.settings_rounded, label: l10n.menuSettings),
    ];

    return AnimatedContainer(
      duration: AppSideMenu.animationDuration,
      curve: Curves.easeInOut,
      width: isExpanded
          ? AppSideMenu.expandedWidth
          : AppSideMenu.collapsedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          if (isExpanded) _Header(isExpanded: isExpanded),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              itemCount: items.length,
              separatorBuilder: (_, index) {
                if (items[index].hasDividerAfter) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  );
                }
                return const SizedBox(height: AppSpacing.xs);
              },
              itemBuilder: (context, index) {
                return _SideMenuItem(
                  icon: items[index].icon,
                  label: items[index].label,
                  isSelected: index == selectedIndex,
                  isExpanded: isExpanded,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          if (showToggleButton) ...[
            Divider(
              height: 1,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _ToggleButton(isExpanded: isExpanded, onPressed: onToggleExpanded),
          ],
        ],
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final bool hasDividerAfter;

  const _MenuItemData({
    required this.icon,
    required this.label,
    this.hasDividerAfter = false,
  });
}

class _Header extends StatelessWidget {
  const _Header({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SizedBox(
        height: 80,
        child: Image.asset(
          'assets/images/logo-servicebo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.business_rounded,
            size: AppIconSizes.xl,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final foregroundColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: isSelected ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        hoverColor: colorScheme.primary.withValues(alpha: 0.04),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: AppSideMenu.animationDuration,
          curve: Curves.easeInOut,
          height: 52,
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? AppSpacing.md : AppSpacing.none,
          ),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: AppIconSizes.md),
              if (isExpanded) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      letterSpacing: isSelected ? 0.2 : 0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.isExpanded, required this.onPressed});

  final bool isExpanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: isExpanded ? AppSpacing.md : AppSpacing.sm,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Align(
        alignment: isExpanded ? Alignment.centerRight : Alignment.center,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
          ),
          icon: AnimatedRotation(
            turns: isExpanded ? 0 : 0.5,
            duration: AppSideMenu.animationDuration,
            child: Icon(
              Icons.chevron_left_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
