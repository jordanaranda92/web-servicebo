import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/theme_constants.dart';
import '../../../app/theme/theme_extensions.dart';
import '../bloc/feedback_cubit.dart';
import '../bloc/feedback_state.dart';

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<FeedbackCubit, FeedbackState>(
      buildWhen: (previous, current) =>
          previous.message != current.message ||
          previous.isSuccess != current.isSuccess,
      builder: (context, feedback) {
        if (!feedback.hasMessage) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: SizedBox(
            height: 40,
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              color: feedback.isSuccess
                  ? Theme.of(context).extension<CustomColors>()?.success
                  : colorScheme.error,
              shadowColor:
                  (feedback.isSuccess
                          ? (Theme.of(
                                  context,
                                ).extension<CustomColors>()?.success ??
                                colorScheme.primary)
                          : colorScheme.error)
                      .withValues(alpha: AppOpacity.disabled),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      feedback.isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 18,
                      color: colorScheme.onError,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      feedback.message!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
