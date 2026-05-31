import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';

/// Footer for the read-only orders view.
///
/// Shows the last modification timestamp and a pulsating dot indicating
/// whether the Firestore connection is active.
class ReadonlyFooter extends StatefulWidget {
  const ReadonlyFooter({
    super.key,
    required this.lastModifiedAt,
    required this.isConnected,
  });

  final DateTime? lastModifiedAt;
  final bool isConnected;

  @override
  State<ReadonlyFooter> createState() => _ReadonlyFooterState();
}

class _ReadonlyFooterState extends State<ReadonlyFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ReadonlyFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isConnected && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final formattedDate = widget.lastModifiedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(widget.lastModifiedAt!)
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: widget.isConnected
                ? l10n.ordersLiveConnected
                : l10n.ordersLiveDisconnected,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isConnected
                        ? (Theme.of(
                                    context,
                                  ).extension<CustomColors>()?.success ??
                                  Colors.green)
                              .withValues(alpha: _pulseAnimation.value)
                        : colorScheme.outline,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.ordersLastModified(formattedDate),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
