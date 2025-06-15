import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_notifier.dart';

/// Simple theme switch widget
/// Updates SettingsProvider which then syncs with ThemeNotifier
class SimpleThemeSwitch extends StatelessWidget {
  const SimpleThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, ThemeNotifier>(
      builder: (context, settingsProvider, themeNotifier, child) {
        return SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Switch between light and dark themes'),
          value: settingsProvider.settings.darkMode,
          onChanged: settingsProvider.isLoading || themeNotifier.isLoading
              ? null // Disable during loading
              : (value) async {
                  // Update settings provider
                  await settingsProvider.updateSettings(darkMode: value);
                  // Sync with theme notifier
                  await themeNotifier.setDarkMode(value);
                },
          secondary: Icon(
            settingsProvider.settings.darkMode
                ? Icons.dark_mode
                : Icons.light_mode,
            color: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }
}
