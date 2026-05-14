import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userResult = await _authRepo.getCurrentUser();
    String? uid;
    userResult.fold((_) {}, (user) {
      if (user != null) {
        uid = user.uid;
      }
    });

    if (uid != null) {
      final nameResult = await _authRepo.getUserName(uid!);
      nameResult.fold((_) {}, (name) {
        if (mounted && name != null) {
          _controller.text = name;
        }
      });
    }

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
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsUserNameLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _controller,
                  enabled: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
