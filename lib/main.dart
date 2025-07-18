import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_notifier.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/service_locator.dart';

import 'services/storage_service.dart';
import 'services/file_cleanup_service.dart';
import 'services/performance_monitor.dart';
import 'widgets/theme_wrapper.dart';
import 'theme/material_light_theme.dart';
import 'theme/dracula_theme.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge display for a modern look
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  // Initialize logger
  await AppLogger.init();

  // Initialize StorageService (must be first)
  await StorageService.initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize enhanced file cleanup service
  await FileCleanupService.instance.init();
  
  // Reset service locator to ensure clean state on app start
  await ServiceLocator.instance.reset();

  // Initialize performance monitoring in debug mode
  if (kDebugMode) {
    PerformanceMonitor.instance.startMonitoring();
  }

  runApp(MyApp(prefs: prefs));
}

/// Initialize services asynchronously and trigger provider rebuild
Future<void> _initializeServicesAsync(SettingsProvider settingsProvider, BuildContext context) async {
  try {
    AppLogger.info('Starting async service initialization...');
    await ServiceLocator.instance.initialize(settingsProvider);
    
    // Trigger a rebuild of the ChatProvider after services are initialized
    if (context.mounted) {
      // The ChangeNotifierProxyProvider will automatically update when services are ready
      // No need to manually trigger notifications
    }
    
    AppLogger.info('Async service initialization completed');
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize services asynchronously', e, stackTrace);
  }
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
        // Create independent providers first
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier(),
        ),

        // Create ChatProvider using service locator with proper async initialization
        ChangeNotifierProxyProvider<SettingsProvider, ChatProvider?>(
          create: (_) => null,
          update: (context, settingsProvider, previous) {
            // Only create ChatProvider after SettingsProvider is ready
            if (settingsProvider.isLoading) {
              return previous;
            }
            
            // Return existing provider if already created and services are still initialized
            if (previous != null && ServiceLocator.instance.isInitialized) {
              return previous;
            }
            
            // Initialize service locator synchronously if not done
            // This ensures proper dependency injection setup
            if (!ServiceLocator.instance.isInitialized) {
              // Schedule async initialization but return null for now
              _initializeServicesAsync(settingsProvider, context);
              return null;
            }
            
            // Create ChatProvider with all required services
            try {
              return ChatProvider(
                chatHistoryService: ServiceLocator.instance.chatHistoryService,
                settingsProvider: settingsProvider,
                modelManager: ServiceLocator.instance.modelManager,
                chatStateManager: ServiceLocator.instance.chatStateManager,
                messageStreamingService: ServiceLocator.instance.messageStreamingService,
                chatTitleGenerator: ServiceLocator.instance.chatTitleGenerator,
                fileProcessingManager: ServiceLocator.instance.fileProcessingManager,
                thinkingContentProcessor: ServiceLocator.instance.thinkingContentProcessor,
              );
            } catch (e) {
              AppLogger.error('Failed to create ChatProvider', e);
              return null;
            }
          },
        ),
      ],
      // Use a custom widget to handle theme synchronization
      child: const _AppContent(),
    );
  }
}

/// Handles theme synchronization and app routing
class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> {
  @override
  void initState() {
    super.initState();
    // Set up theme synchronization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _synchronizeTheme();
    });
  }

  void _synchronizeTheme() {
    final settingsProvider = context.read<SettingsProvider>();
    final themeNotifier = context.read<ThemeNotifier>();

    // Listen to settings changes and update theme accordingly
    settingsProvider.addListener(() {
      final shouldBeDark = settingsProvider.settings.darkMode;
      if (themeNotifier.isDarkMode != shouldBeDark) {
        themeNotifier.setDarkMode(shouldBeDark);
      }
    });

    // Initial sync
    if (!settingsProvider.isLoading) {
      final shouldBeDark = settingsProvider.settings.darkMode;
      if (themeNotifier.isDarkMode != shouldBeDark) {
        themeNotifier.setDarkMode(shouldBeDark);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'OllamaVerse',
          theme: materialLightTheme(),
          darkTheme: draculaDarkTheme(),
          themeMode:
              themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const ThemeWrapper(
                  child: ChatScreen(),
                ),
            '/settings': (context) => const ThemeWrapper(
                  child: SettingsScreen(),
                ),
          },
        );
      },
    );
  }
}
