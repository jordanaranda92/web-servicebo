import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/orders_presence_cubit.dart';
import '../bloc/orders_presence_state.dart';
import 'user_badge.dart';

class OrdersTableFooter extends StatelessWidget {
  const OrdersTableFooter({super.key, this.trailing, this.compact = false});

  final Widget? trailing;

  /// When `true`, uses minimal padding (for read-only fullscreen mode).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            )
          : const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
      child: Row(
        children: [
          Expanded(child: _ConnectedUsersSection()),
          ?trailing,
        ],
      ),
    );
  }
}

class _ConnectedUsersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    late final OrdersPresenceCubit presenceCubit;
    try {
      presenceCubit = context.read<OrdersPresenceCubit>();
    } catch (_) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<OrdersPresenceCubit, OrdersPresenceState>(
      buildWhen: (previous, current) =>
          previous.connectedUsers != current.connectedUsers ||
          previous.cursors != current.cursors,
      builder: (context, state) {
        if (state.connectedUsers <= 0) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final cursors = state.cursors.values.toList();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${l10n.ordersTodayConnectedUsers(state.connectedUsers)}: ',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            UserBadge(
              name: presenceCubit.userName,
              color: presenceCubit.myColor,
            ),
            ...cursors.map(
              (cursor) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: UserBadge(name: cursor.userName, color: cursor.color),
              ),
            ),
          ],
        );
      },
    );
  }
}
