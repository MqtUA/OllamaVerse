import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/chat_history_service.dart';
import 'services/settings_service.dart';
import 'services/file_cleanup_service.dart';
import 'services/performance_monitor.dart';
import 'widgets/animated_theme_switcher.dart';

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
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // Trigger cleanup when app is resumed
      FileCleanupService.instance.forceCleanup();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Dispose cleanup service when app is paused/closed
      FileCleanupService.instance.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Create the SettingsProvider first
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
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'OllamaVerse',
            theme: settingsProvider.lightTheme,
            darkTheme: settingsProvider.darkTheme,
            themeMode: settingsProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => AnimatedThemeSwitcher(
                    themeMode: settingsProvider.themeMode,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    child: const ChatScreen(),
                  ),
              '/settings': (context) => AnimatedThemeSwitcher(
                    themeMode: settingsProvider.themeMode,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    child: const SettingsScreen(),
                  ),
            },
          );
        },
      ),
    );
  }
}
