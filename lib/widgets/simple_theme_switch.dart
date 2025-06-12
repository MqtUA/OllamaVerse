import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_notifier.dart';

/// Simple theme switch widget
/// Just a clean SwitchListTile that toggles theme immediately
class SimpleThemeSwitch extends StatelessWidget {
  const SimpleThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Switch between light and dark themes'),
          value: themeNotifier.isDarkMode,
          onChanged: themeNotifier.isLoading
              ? null // Disable during loading
              : (value) => themeNotifier.toggleTheme(),
          secondary: Icon(
            themeNotifier.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }
}
