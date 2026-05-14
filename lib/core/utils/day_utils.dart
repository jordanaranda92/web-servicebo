import '../../app/localization/l10n/app_localizations.dart';

const dayOrder = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

String localizedDay(String dayCode, AppLocalizations l10n) {
  return switch (dayCode) {
    'monday' => l10n.dayMonday,
    'tuesday' => l10n.dayTuesday,
    'wednesday' => l10n.dayWednesday,
    'thursday' => l10n.dayThursday,
    'friday' => l10n.dayFriday,
    'saturday' => l10n.daySaturday,
    'sunday' => l10n.daySunday,
    _ => dayCode,
  };
}
