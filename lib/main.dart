import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'utils/file_utils.dart';
import 'theme/dracula_theme.dart';
import 'theme/material_light_theme.dart';
import 'services/chat_history_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await AppLogger.init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Start periodic file cleanup
  _startFileCleanup();

  runApp(MyApp(prefs: prefs));
}

// Start periodic file cleanup
void _startFileCleanup() {
  // Clean up files every 24 hours
  Future.delayed(const Duration(hours: 24), () async {
    await FileUtils.cleanupOldFiles();
    _startFileCleanup(); // Schedule next cleanup
  });
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
      // Clean up files when app is resumed
      FileUtils.cleanupOldFiles();
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
            key: const ValueKey('main_app'),
            title: 'OllamaVerse',
            theme: materialLightTheme(),
            darkTheme: draculaDarkTheme(),
            themeMode: settingsProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const ChatScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
