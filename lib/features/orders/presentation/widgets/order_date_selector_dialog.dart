import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n/app_localizations.dart';

/// Shows a dialog that lets the user pick a date within [today-7, today+2].
///
/// For each date, the dialog shows the number of clients via
/// [onFetchClientCount]. Returns the selected [DateTime] or `null` if
/// cancelled.
Future<DateTime?> showOrderDateSelectorDialog(
  BuildContext context, {
  required DateTime currentDate,
  required Future<int?> Function(DateTime date) onFetchClientCount,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _OrderDateSelectorDialog(
      currentDate: currentDate,
      onFetchClientCount: onFetchClientCount,
    ),
  );
}

class _OrderDateSelectorDialog extends StatefulWidget {
  const _OrderDateSelectorDialog({
    required this.currentDate,
    required this.onFetchClientCount,
  });

  final DateTime currentDate;
  final Future<int?> Function(DateTime date) onFetchClientCount;

  @override
  State<_OrderDateSelectorDialog> createState() =>
      _OrderDateSelectorDialogState();
}

class _OrderDateSelectorDialogState extends State<_OrderDateSelectorDialog> {
  late DateTime _selectedDate;
  late final List<DateTime> _dates;
  final Map<String, int?> _clientCounts = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.currentDate.year,
      widget.currentDate.month,
      widget.currentDate.day,
    );

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    _dates = List.generate(
      10,
      (i) => todayOnly.subtract(Duration(days: 7 - i)),
    );

    // Pre-fetch client count for the current date
    _fetchClientCount(_selectedDate);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _fetchClientCount(DateTime date) async {
    final key = _dateKey(date);
    if (_clientCounts.containsKey(key) || _loading.contains(key)) return;

    setState(() => _loading.add(key));
    final count = await widget.onFetchClientCount(date);
    if (!mounted) return;
    setState(() {
      _loading.remove(key);
      _clientCounts[key] = count;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayFormat = DateFormat('EEE', 'es');
    final dayNumber = DateFormat('d', 'es');

    final selectedKey = _dateKey(_selectedDate);
    final clientCount = _clientCounts[selectedKey];
    final isLoadingSelected = _loading.contains(selectedKey);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(color: colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ordersDateSelectorTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM', 'es').format(_selectedDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            // ── Date grid ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: _dates.length,
                itemBuilder: (context, index) {
                  final date = _dates[index];
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isCurrentDay = _isToday(date);
                  final dayStr = dayFormat.format(date).toUpperCase();
                  final numStr = dayNumber.format(date);

                  final bgColor = isSelected
                      ? colorScheme.primary
                      : isCurrentDay
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow;
                  final fgColor = isSelected
                      ? colorScheme.onPrimary
                      : isCurrentDay
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface;

                  return Material(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedDate = date);
                        _fetchClientCount(date);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: fgColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            numStr,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: fgColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isCurrentDay) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Summary card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoadingSelected
                    ? const Padding(
                        key: ValueKey('loading'),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        key: ValueKey('summary-$selectedKey'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: clientCount != null && clientCount > 0
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                )
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              clientCount != null && clientCount > 0
                                  ? Icons.people_outline_rounded
                                  : Icons.event_busy_outlined,
                              size: 18,
                              color: clientCount != null && clientCount > 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              clientCount == null
                                  ? l10n.ordersDateSelectorNoOrders
                                  : l10n.ordersDateSelectorClients(clientCount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: clientCount != null && clientCount > 0
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.ordersDateSelectorCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      child: Text(l10n.ordersDateSelectorAccept),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
