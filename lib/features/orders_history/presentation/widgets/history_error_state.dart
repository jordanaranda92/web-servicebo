import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/orders_history_state.dart';

class HistoryErrorState extends StatelessWidget {
  const HistoryErrorState({
    super.key,
    required this.errorType,
    required this.onRetry,
  });

  final OrdersHistoryErrorType errorType;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppIconSizes.xl,
            color: colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage(l10n),
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.ordersHistoryRetry),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n) {
    switch (errorType) {
      case OrdersHistoryErrorType.serverError:
        return l10n.ordersHistoryErrorServer;
      case OrdersHistoryErrorType.unknown:
        return l10n.ordersHistoryErrorUnknown;
    }
  }
}
