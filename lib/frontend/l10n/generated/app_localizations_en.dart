// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MY PRINT SHOP';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Use the dark color theme across the app';

  @override
  String get languageSubtitle => 'English (default)';

  @override
  String get account => 'Account';

  @override
  String get accountDetails => 'Account Details';

  @override
  String get accountDetailsSubtitle => 'Phone, email and account information';

  @override
  String get appLanguageTitle => 'App Language';

  @override
  String get appLanguageNote =>
      'The app is English-only right now. Other languages will be enabled as translations ship.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get active => 'Active';

  @override
  String get selected => 'Selected';
}
