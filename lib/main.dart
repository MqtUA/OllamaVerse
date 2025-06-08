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
  // Reference to providers to avoid using BuildContext in async operations
  ChatProvider? _chatProvider;
  
  @override
  void initState() {
    super.initState();
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Schedule provider initialization after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  @override
  void dispose() {
    // Unregister from lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Initialize provider references safely
  void _initializeProviders() {
    if (!mounted) return;
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground
      // Refresh connections and models after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        // Use the stored provider reference instead of getting it from context
        if (_chatProvider != null) {
          _chatProvider!.refreshModels().catchError((e) {
            // Handle any errors silently to prevent app crashes
            debugPrint('Error refreshing models after resume: $e');
            return true; // Error was handled
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ChatProvider>(
          create: (context) => ChatProvider(Provider.of<SettingsProvider>(context, listen: false)),
          update: (context, settings, previous) => previous ?? ChatProvider(settings),
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
