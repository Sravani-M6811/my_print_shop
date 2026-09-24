import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'account_details_screen.dart';

class _LanguageOption {
  final String code;
  final String name;
  final String? nativeName;
  final bool enabled;
  const _LanguageOption({
    required this.code,
    required this.name,
    this.nativeName,
    this.enabled = false,
  });
}

/// App settings screen (reached from the Profile tab).
///
/// Groups app-level preferences:
///   * Appearance — Dark Mode (persisted through [AppState]).
///   * Language — English today, with an i18n-ready list where additional
///     languages are visible but labelled "Coming soon" so the architecture is
///     honest instead of pretending translations exist.
///   * Account — a link to the account details screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<_LanguageOption> _languages = [
    _LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      enabled: true,
    ),
    _LanguageOption(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    _LanguageOption(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    _LanguageOption(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    _LanguageOption(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    _LanguageOption(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
    _LanguageOption(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
    _LanguageOption(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
  ];

  String _currentLanguageName(String code) {
    for (final lang in _languages) {
      if (lang.code == code) return lang.name;
    }
    return 'en';
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppLocalizations.of(ctx).appLanguageTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppLocalizations.of(ctx).appLanguageNote,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 8),
              for (final lang in _languages)
                ListTile(
                  dense: true,
                  leading: Icon(
                    lang.enabled
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: lang.enabled
                        ? const Color(0xFF6C5CE7)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  title: Row(
                    children: [
                      Text(lang.name),
                      if (lang.nativeName != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          lang.nativeName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: lang.enabled
                      ? Text(AppLocalizations.of(ctx).active)
                      : Text(AppLocalizations.of(ctx).comingSoon),
                  trailing: lang.enabled
                      ? Text(
                          AppLocalizations.of(ctx).selected,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF6C5CE7),
                          ),
                        )
                      : null,
                  onTap: lang.enabled
                      ? () => Provider.of<AppState>(ctx, listen: false)
                          .setLocale(lang.code)
                      : () => ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${lang.name} is coming soon. English remains active.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          ),
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _sectionHeader(context, l10n.appearance),
          SwitchListTile(
            title: Text(l10n.darkMode),
            subtitle: Text(l10n.darkModeSubtitle),
            secondary: Icon(
              appState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: appState.isDarkMode ? Colors.yellow : Colors.blue,
            ),
            value: appState.isDarkMode,
            onChanged: (_) => appState.toggleTheme(),
          ),
          _sectionHeader(context, l10n.language),
          ListTile(
            leading: const Icon(Icons.translate, color: Color(0xFF6C5CE7)),
            title: Text(l10n.language),
            subtitle: Text(
              appState.localeCode == 'en'
                  ? l10n.languageSubtitle
                  : '${l10n.selected}: ${_currentLanguageName(appState.localeCode)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageSheet(context),
          ),
          _sectionHeader(context, l10n.account),
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: Color(0xFF6C5CE7)),
            title: Text(l10n.accountDetails),
            subtitle: Text(l10n.accountDetailsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AccountDetailsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
