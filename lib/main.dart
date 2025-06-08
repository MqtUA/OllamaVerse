import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';

void main() {
  // Initialize logger
  AppLogger.init();
  
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
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
    if (state == AppLifecycleState.resumed && mounted) {
      // App has come to the foreground
      // Refresh connections and models after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        
        try {
          // Get the ChatProvider directly when needed
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          chatProvider.refreshModels().catchError((e) {
            // Handle any errors silently to prevent app crashes
            debugPrint('Error refreshing models after resume: $e');
            return true; // Error was handled
          });
        } catch (e) {
          debugPrint('Error accessing ChatProvider: $e');
        }
      });
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
            final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
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
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
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
