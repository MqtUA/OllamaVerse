import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_notifier.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/chat_history_service.dart';
import 'services/settings_service.dart';
import 'services/file_cleanup_service.dart';
import 'services/performance_monitor.dart';
import 'widgets/animated_theme_switcher.dart';
import 'theme/material_light_theme.dart';
import 'theme/dracula_theme.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await AppLogger.init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize enhanced file cleanup service
  await FileCleanupService.instance.init();

  // Initialize performance monitoring in debug mode
  if (kDebugMode) {
    PerformanceMonitor.instance.startMonitoring();
  }

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister from lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes - removed excessive cleanup triggering
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Dispose cleanup service when app is paused/closed
      FileCleanupService.instance.dispose();
    }
    // Note: Cleanup now only runs on app start and manual triggers
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Create the ThemeNotifier first (simple theme management)
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),

        // Create the SettingsProvider
        ChangeNotifierProvider(create: (_) => SettingsProvider()),

        // Create the ChatProvider with the required parameters
        ChangeNotifierProxyProvider<SettingsProvider, ChatProvider>(
          // Create a new ChatProvider with the required parameters
          create: (context) {
            final settingsProvider =
                Provider.of<SettingsProvider>(context, listen: false);
            final chatHistoryService = ChatHistoryService();
            final settingsService = SettingsService(widget.prefs);
            return ChatProvider(
              chatHistoryService: chatHistoryService,
              settingsService: settingsService,
              settingsProvider: settingsProvider,
            );
          },
          // Update the ChatProvider when SettingsProvider changes
          update: (context, settingsProvider, previous) {
            if (previous == null) {
              final chatHistoryService = ChatHistoryService();
              final settingsService = SettingsService(widget.prefs);
              return ChatProvider(
                chatHistoryService: chatHistoryService,
                settingsService: settingsService,
                settingsProvider: settingsProvider,
              );
            }
            // Return the previous instance as it already has listeners set up
            return previous;
          },
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            title: 'OllamaVerse',
            theme: materialLightTheme(),
            darkTheme: draculaDarkTheme(),
            themeMode:
                themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => AnimatedThemeSwitcher(
                    themeMode: themeNotifier.isDarkMode
                        ? ThemeMode.dark
                        : ThemeMode.light,
                    duration: const Duration(milliseconds: 30), // Ultra-fast
                    curve: Curves.linear,
                    child: const ChatScreen(),
                  ),
              '/settings': (context) => AnimatedThemeSwitcher(
                    themeMode: themeNotifier.isDarkMode
                        ? ThemeMode.dark
                        : ThemeMode.light,
                    duration: const Duration(milliseconds: 30), // Ultra-fast
                    curve: Curves.linear,
                    child: const SettingsScreen(),
                  ),
            },
          );
        },
      ),
    );
  }
}
