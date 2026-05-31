import 'package:flutter/material.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/orders_state.dart';

class OrdersErrorState extends StatelessWidget {
  const OrdersErrorState({
    super.key,
    required this.errorType,
    required this.onRetry,
  });

  final OrdersErrorType errorType;
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
            label: Text(l10n.ordersRetry),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n) {
    switch (errorType) {
      case OrdersErrorType.templateNotFound:
        return l10n.ordersErrorTemplateNotFound;
      case OrdersErrorType.fileSystemError:
        return l10n.ordersErrorFileSystem;
      case OrdersErrorType.invalidFormat:
        return l10n.ordersErrorInvalidFormat;
      case OrdersErrorType.driveNotConfigured:
        return l10n.ordersNoFolderMessage;
      case OrdersErrorType.configNotAvailable:
        return l10n.ordersErrorFileSystem;
      case OrdersErrorType.unknown:
        return l10n.ordersErrorUnknown;
    }
  }
}
