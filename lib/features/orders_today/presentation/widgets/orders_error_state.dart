import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/orders_today_state.dart';

class OrdersErrorState extends StatelessWidget {
  const OrdersErrorState({
    super.key,
    required this.errorType,
    required this.onRetry,
  });

  final OrdersTodayErrorType errorType;
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
            label: Text(l10n.ordersTodayRetry),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n) {
    switch (errorType) {
      case OrdersTodayErrorType.templateNotFound:
        return l10n.ordersTodayErrorTemplateNotFound;
      case OrdersTodayErrorType.fileSystemError:
        return l10n.ordersTodayErrorFileSystem;
      case OrdersTodayErrorType.invalidFormat:
        return l10n.ordersTodayErrorInvalidFormat;
      case OrdersTodayErrorType.driveNotConfigured:
        return l10n.ordersTodayNoFolderMessage;
      case OrdersTodayErrorType.configNotAvailable:
        return l10n.ordersTodayErrorFileSystem;
      case OrdersTodayErrorType.unknown:
        return l10n.ordersTodayErrorUnknown;
    }
  }
}
