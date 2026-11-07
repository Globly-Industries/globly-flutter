import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_state.dart';
import 'common.dart';

/// Language choices: device default, English, Latvian.
const appLanguages = <String?, String>{null: '', 'en': 'English', 'lv': 'Latviešu'};

String languageLabel(BuildContext context, String? code) =>
    code == null ? context.l10n.systemLanguage : appLanguages[code]!;

/// Icon button that opens the language menu (used on the login screen).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    return PopupMenuButton<String?>(
      tooltip: context.l10n.language,
      icon: const Icon(Icons.translate_rounded),
      initialValue: settings.locale?.languageCode,
      onSelected: (code) => settings.setLocale(code == null ? null : Locale(code)),
      itemBuilder: (_) => [
        for (final code in appLanguages.keys)
          CheckedPopupMenuItem<String?>(
            value: code,
            checked: settings.locale?.languageCode == code,
            child: Text(languageLabel(context, code)),
          ),
      ],
    );
  }
}
