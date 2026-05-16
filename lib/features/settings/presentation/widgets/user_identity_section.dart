import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../core/utils/category_color_utils.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import 'settings_section.dart';

class UserIdentitySection extends StatefulWidget {
  const UserIdentitySection({super.key});

  @override
  State<UserIdentitySection> createState() => _UserIdentitySectionState();
}

class _UserIdentitySectionState extends State<UserIdentitySection> {
  late final TextEditingController _controller;
  final _authRepo = sl<AuthRepository>();
  Color? _userColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profileResult = await _authRepo.getCurrentUserWithProfile();
    profileResult.fold((_) {}, (user) {
      if (user != null && mounted) {
        _controller.text = user.userName ?? '';
        _userColor = tryParseHex(user.color) ?? PresenceColors.palette.first;
      }
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l10n.settingsUserIdentityTitle,
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsUserIdentityDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsUserNameLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _controller,
                      enabled: false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_userColor != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _userColor,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
