import 'package:flutter/material.dart';

import '../../../../app/theme/theme_constants.dart';

class FabItem {
  const FabItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    required this.colorScheme,
    required this.items,
    this.onOpenChanged,
  });

  final ColorScheme colorScheme;
  final List<FabItem> items;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<ExpandableFab> createState() => ExpandableFabState();
}

class ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onOpenChanged?.call(_isOpen);
  }

  void close() {
    if (_isOpen) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expandable items
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: widget.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        elevation: AppElevation.low,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        color: colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            item.label,
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FloatingActionButton.small(
                        heroTag: null,
                        onPressed: () {
                          _toggle();
                          item.onTap();
                        },
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        child: Icon(item.icon),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.more_vert_rounded),
          ),
        ),
      ],
    );
  }
}
