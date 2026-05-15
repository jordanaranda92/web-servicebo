import '../../../../app/localization/l10n/app_localizations.dart';

List<String> localizedWeekdays(AppLocalizations l10n) => [
  l10n.weekdayMonday,
  l10n.weekdayTuesday,
  l10n.weekdayWednesday,
  l10n.weekdayThursday,
  l10n.weekdayFriday,
  l10n.weekdaySaturday,
  l10n.weekdaySunday,
];

List<String> localizedMonths(AppLocalizations l10n) => [
  l10n.monthJanuary,
  l10n.monthFebruary,
  l10n.monthMarch,
  l10n.monthApril,
  l10n.monthMay,
  l10n.monthJune,
  l10n.monthJuly,
  l10n.monthAugust,
  l10n.monthSeptember,
  l10n.monthOctober,
  l10n.monthNovember,
  l10n.monthDecember,
];

String formatCurrencyEur(double amount) {
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }
  return '$buffer,$decPart €';
}
