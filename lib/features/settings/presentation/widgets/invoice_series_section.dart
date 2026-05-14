import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../../../app/theme/theme_extensions.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_section.dart';

class InvoiceSeriesSection extends StatefulWidget {
  const InvoiceSeriesSection({super.key});

  @override
  State<InvoiceSeriesSection> createState() => _InvoiceSeriesSectionState();
}

class _InvoiceSeriesSectionState extends State<InvoiceSeriesSection> {
  late final TextEditingController _controller;
  final _settingsRepo = sl<SettingsRepository>();
  bool _showSavedBanner = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadInvoiceSeries();
  }

  Future<void> _loadInvoiceSeries() async {
    final result = await _settingsRepo.getInvoiceSeries();
    if (!mounted) return;
    result.fold((_) => setState(() => _isLoading = false), (series) {
      _controller.text = series ?? '';
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsInvoiceSeriesEmpty)));
      return;
    }
    final result = await _settingsRepo.saveInvoiceSeries(text);
    if (!mounted) return;
    result.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsInvoiceSeriesSaveError)),
        );
      },
      (_) {
        setState(() => _showSavedBanner = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSavedBanner = false);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l10n.settingsFacturaDirectaTitle,
      icon: Icons.receipt_long_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsFacturaDirectaDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsInvoiceSeriesLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _controller,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                height: 42,
                width: 42,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                  ),
                  child: const Icon(Icons.save_rounded),
                ),
              ),
              if (_showSavedBanner) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<CustomColors>()?.success,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.settingsInvoiceSeriesSaved,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
