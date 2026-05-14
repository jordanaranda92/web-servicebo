import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/theme/theme_constants.dart';
import '../../domain/entities/order_date_info.dart';

class HistoryDateList extends StatefulWidget {
  const HistoryDateList({
    super.key,
    required this.dates,
    required this.onDateSelected,
  });

  final List<OrderDateInfo> dates;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<HistoryDateList> createState() => _HistoryDateListState();
}

class _HistoryDateListState extends State<HistoryDateList> {
  final _scrollController = ScrollController();
  late List<_Section> _sections;
  late List<GlobalKey> _sectionKeys;
  late String _lastWeekLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastWeekLabel = AppLocalizations.of(context)!.ordersHistoryLastWeek;
    _sections = _buildSections(widget.dates);
    _sectionKeys = List.generate(_sections.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant HistoryDateList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dates != widget.dates) {
      _sections = _buildSections(widget.dates);
      _sectionKeys = List.generate(_sections.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
            ),
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final section = _sections[index];
              if (section.isYear) {
                return Padding(
                  key: _sectionKeys[index],
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : AppSpacing.lg,
                    bottom: AppSpacing.xs,
                  ),
                  child: _YearHeader(title: section.title),
                );
              }
              return Column(
                key: _sectionKeys[index],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: section.title),
                  ...section.dates.map(
                    (info) => _DateTile(
                      info: info,
                      onTap: () => widget.onDateSelected(info.date),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _SectionNav(sections: _sections, onTap: _scrollToSection),
      ],
    );
  }

  void _scrollToSection(int index) {
    final key = _sectionKeys[index];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<_Section> _buildSections(List<OrderDateInfo> dates) {
    if (dates.isEmpty) return [];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final lastWeek = <OrderDateInfo>[];
    final byMonth = <String, List<OrderDateInfo>>{};
    final lastWeekSet = <DateTime>{};

    for (final info in dates) {
      if (!info.date.isBefore(weekAgo)) {
        lastWeek.add(info);
        lastWeekSet.add(info.date);
      }
      final key = DateFormat('yyyy-MM').format(info.date);
      byMonth.putIfAbsent(key, () => []).add(info);
    }

    final sections = <_Section>[];

    if (lastWeek.isNotEmpty) {
      sections.add(_Section(title: _lastWeekLabel, dates: lastWeek));
    }

    int? currentYear;
    for (final entry in byMonth.entries) {
      final monthDates = entry.value
          .where((info) => !lastWeekSet.contains(info.date))
          .toList();
      if (monthDates.isEmpty) continue;
      final sampleDate = monthDates.first.date;
      final year = sampleDate.year;
      if (currentYear != year) {
        currentYear = year;
        sections.add(_Section(title: '$year', dates: const [], isYear: true));
      }
      final monthLabel = DateFormat('MMMM', 'es').format(sampleDate);
      final capitalized = monthLabel[0].toUpperCase() + monthLabel.substring(1);
      sections.add(_Section(title: capitalized, dates: monthDates));
    }

    return sections;
  }
}

class _Section {
  const _Section({
    required this.title,
    required this.dates,
    this.isYear = false,
  });
  final String title;
  final List<OrderDateInfo> dates;
  final bool isYear;
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.sections, required this.onTap});

  final List<_Section> sections;
  final ValueChanged<int> onTap;

  static const _width = 200.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Container(
        width: _width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                AppLocalizations.of(context)!.ordersHistoryNavigation,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  if (section.isYear) {
                    return Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : AppSpacing.sm,
                        bottom: AppSpacing.xs,
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                      ),
                      child: Text(
                        section.title,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return InkWell(
                    onTap: () => onTap(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            section.title ==
                                    AppLocalizations.of(
                                      context,
                                    )!.ordersHistoryLastWeek
                                ? Icons.access_time_rounded
                                : Icons.calendar_month_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              section.title,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${section.dates.length}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Text(
        title,
        style: textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.info, required this.onTap});

  final OrderDateInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateText = DateFormat(
      "dd 'de' MMMM 'de' yyyy",
      'es',
    ).format(info.date);
    final dayName = DateFormat('EEEE', 'es').format(info.date);
    final dayNameCapitalized = dayName[0].toUpperCase() + dayName.substring(1);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
        title: Text(dateText, style: textTheme.bodyLarge),
        subtitle: Text(
          '$dayNameCapitalized · ${l10n.ordersHistoryDateClients(info.clientCount)} · ${l10n.ordersHistoryDateProducts(info.productCount)}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
    );
  }
}
