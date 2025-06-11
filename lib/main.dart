import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'utils/file_utils.dart';
import 'theme/dracula_theme.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await AppLogger.init();

  // Start periodic file cleanup
  _startFileCleanup();

  runApp(const MyApp());
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
  const MyApp({super.key});

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
            final settingsProvider = Provider.of<SettingsProvider>(
              context,
              listen: false,
            );
            final ollamaService = settingsProvider.getOllamaService();
            return ChatProvider(
              ollamaService: ollamaService,
              settingsProvider: settingsProvider,
            );
          },
          // Update the ChatProvider when SettingsProvider changes
          update: (context, settingsProvider, previous) {
            if (previous == null) {
              final ollamaService = settingsProvider.getOllamaService();
              return ChatProvider(
                ollamaService: ollamaService,
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              brightness: Brightness.light,
            ),
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
