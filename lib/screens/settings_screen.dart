import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';
import '../services/file_cleanup_service.dart';
import '../services/file_content_cache.dart';
import '../services/performance_monitor.dart';
import '../widgets/simple_theme_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _authTokenController;
  late TextEditingController _systemPromptController;

  bool _isTesting = false;
  String _appVersion = '';
  bool _showAuthToken = false;

  // Stream controller for performance monitoring (only in debug builds)
  StreamController<PerformanceStats>? _performanceStreamController;
  Timer? _performanceTimer;

  @override
  void initState() {
    super.initState();

    // Initialize controllers without values - will be set from Consumer
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _authTokenController = TextEditingController();
    _systemPromptController = TextEditingController();

    // Initialize performance monitoring stream only in debug builds
    if (kDebugMode) {
      _performanceStreamController =
          StreamController<PerformanceStats>.broadcast();
      _performanceTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) {
          if (mounted &&
              _performanceStreamController != null &&
              !_performanceStreamController!.isClosed) {
            _performanceStreamController!
                .add(PerformanceMonitor.instance.getStats());
          }
        },
      );
    }

    // Load app version and auth token
    _loadAppVersion();
    _loadAuthToken();

    // Initialize values from provider after first frame to avoid race condition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings =
            Provider.of<SettingsProvider>(context, listen: false).settings;
        _hostController.text = settings.ollamaHost;
        _portController.text = settings.ollamaPort.toString();
        _systemPromptController.text = settings.systemPrompt;

        // Variables are now read directly from provider - no local state needed
      }
    });
  }

  // Load auth token securely
  Future<void> _loadAuthToken() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final authToken = settingsProvider.authToken;
    if (authToken != null) {
      _authTokenController.text = '••••••••••••••••'; // Show placeholder
    }
  }

  // Load app version from package info
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _authTokenController.dispose();
    _systemPromptController.dispose();

    // Dispose of performance monitoring resources
    _performanceTimer?.cancel();
    _performanceStreamController?.close();

    super.dispose();
  }

  // Handle saving settings and checking connection
  Future<void> _saveAndCheckConnection() async {
    setState(() {
      _isTesting = true;
    });

    try {
      final host = _hostController.text;
      final port = int.tryParse(_portController.text) ?? 11434;
      final authToken = _showAuthToken ? _authTokenController.text : null;

      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      await settingsProvider.updateSettings(
        ollamaHost: host,
        ollamaPort: port,
        authToken: authToken,
      );

      if (!mounted) return;

      final ollamaService = settingsProvider.getOllamaService();
      final isConnected = await ollamaService.testConnection();

      if (!mounted) return;

      if (isConnected) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.refreshModels();

        if (!mounted) return;

        _showSuccessMessage();
      } else {
        _showConnectionFailedDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  // Show success message
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection successful! Models refreshed.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show connection failed dialog
  void _showConnectionFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Failed'),
        content: const Text(
          'Could not connect to the Ollama server. Please check your settings and ensure the server is running.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show error dialog
  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text('Error: $errorMessage'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width <= 600;
    final horizontalPadding = isSmallScreen ? 8.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16.0,
            ),
            children: [
              // Ollama Server Settings Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ollama Server Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isSmallScreen) ...[
                        _buildHostField(),
                        const SizedBox(height: 8),
                        _buildPortField(),
                        const SizedBox(height: 8),
                        _buildAuthTokenField(),
                      ] else
                        Row(
                          children: [
                            Expanded(child: _buildHostField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPortField()),
                          ],
                        ),
                      if (!isSmallScreen) ...[
                        const SizedBox(height: 16),
                        _buildAuthTokenField(),
                      ],
                      const SizedBox(height: 16),
                      _buildTestConnectionButton(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // App Appearance Settings Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appearance Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Font Size:'),
                          Expanded(
                            child: Slider(
                              value: settingsProvider.settings.fontSize,
                              min: 12,
                              max: 24,
                              divisions: 12,
                              label: settingsProvider.settings.fontSize
                                  .toStringAsFixed(1),
                              onChanged: (value) {
                                // Update provider directly - no local state needed
                                settingsProvider.updateSettings(
                                    fontSize: value);
                              },
                            ),
                          ),
                          Text(settingsProvider.settings.fontSize
                              .toStringAsFixed(1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SimpleThemeSwitch(),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Show Live Response'),
                        subtitle: const Text(
                          'See responses as they are generated',
                        ),
                        value: settingsProvider.settings.showLiveResponse,
                        onChanged: (value) {
                          settingsProvider.updateSettings(
                              showLiveResponse: value);
                        },
                      ),
                      const Divider(),

                      // Thinking Bubble Settings Section
                      const ListTile(
                        title: Text(
                          'Thinking Bubble Settings',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Configure how thinking processes are displayed',
                        ),
                        leading: Icon(Icons.psychology, color: Colors.purple),
                      ),
                      SwitchListTile(
                        title: const Text('Expanded by default'),
                        subtitle: const Text(
                          'Show thinking bubbles expanded by default',
                        ),
                        value: settingsProvider
                            .settings.thinkingBubbleDefaultExpanded,
                        onChanged: (value) {
                          settingsProvider.updateSettings(
                              thinkingBubbleDefaultExpanded: value);
                        },
                      ),
                      // Only show auto-collapse setting if thinking bubbles are expanded by default
                      if (settingsProvider
                          .settings.thinkingBubbleDefaultExpanded)
                        SwitchListTile(
                          title: const Text('Auto-collapse After Thinking'),
                          subtitle: const Text(
                            'Automatically collapse thinking bubble when answer appears',
                          ),
                          value: settingsProvider
                              .settings.thinkingBubbleAutoCollapse,
                          onChanged: (value) {
                            settingsProvider.updateSettings(
                                thinkingBubbleAutoCollapse: value);
                          },
                        ),
                      const Divider(),
                      ListTile(
                        title: const Text('Context Length'),
                        subtitle: const Text(
                          'Maximum token context window (default: 4096)',
                        ),
                        trailing: DropdownButton<int>(
                          value: settingsProvider.settings.contextLength,
                          items:
                              [2048, 4096, 8192, 16384, 32768].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              settingsProvider.updateSettings(
                                  contextLength: newValue);
                            }
                          },
                        ),
                      ),

                      // System Prompt Section
                      const Divider(),
                      const ListTile(
                        title: Text('System Prompt'),
                        subtitle: Text(
                          'This prompt will be applied to all new chats',
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: TextField(
                          controller: _systemPromptController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a system prompt...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                          onChanged: (value) {
                            // Save the system prompt when it changes
                            settingsProvider.updateSettings(
                              systemPrompt: value,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'The system prompt helps define the AI assistant\'s behavior. '
                          'For example: "You are a helpful assistant specialized in programming."',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Performance Settings Section (only in debug builds)
              if (kDebugMode) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Performance Monitoring',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Performance monitoring display with real-time stats
                        SwitchListTile(
                          title: const Text('Performance Monitoring'),
                          subtitle: const Text(
                            'Track frame rates and theme switching performance',
                          ),
                          value: true, // Always enabled in debug mode
                          onChanged: null, // Read-only for now
                          secondary: const Icon(
                            Icons.speed,
                            color: Colors.blue,
                          ),
                        ),
                        // Real-time performance statistics
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: StreamBuilder<PerformanceStats>(
                            stream: _performanceStreamController?.stream,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Card(
                                  margin: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'Loading performance data...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              }

                              final stats = snapshot.data!;
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            stats.isPerformant
                                                ? Icons.check_circle
                                                : Icons.warning,
                                            color: stats.isPerformant
                                                ? Colors.green
                                                : Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Status: ${stats.isPerformant ? "Excellent" : "Needs Improvement"}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: stats.isPerformant
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _buildPerformanceRow(
                                          'Frame Time',
                                          '${stats.averageFrameTime.toStringAsFixed(1)}ms',
                                          stats.averageFrameTime < 16.67),
                                      _buildPerformanceRow(
                                          'Frame Drops',
                                          '${stats.frameDropCount}',
                                          stats.frameDropCount < 5),
                                      _buildPerformanceRow(
                                          'Theme Switch',
                                          '${stats.averageThemeSwitchTime.toStringAsFixed(1)}ms',
                                          stats.averageThemeSwitchTime <
                                              50.0), // Fixed threshold to match code
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Performance actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    PerformanceMonitor.instance.resetMetrics();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Performance metrics reset'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Reset'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    PerformanceMonitor.instance
                                        .logPerformanceSummary();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Performance logged to console'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.bug_report, size: 16),
                                  label: const Text('Log'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Storage Settings Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // File cache statistics
                      FutureBuilder<CacheStats>(
                        future: FileContentCache.instance.getCacheStats(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final stats = snapshot.data!;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.folder_special,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'File Cache',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                        const Spacer(),
                                        Text(
                                          stats.formattedSize,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${stats.totalEntries} cached files • Faster file processing',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const Card(
                            margin: EdgeInsets.symmetric(vertical: 4.0),
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text(
                                'Loading cache statistics...',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                      // Storage cleanup actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);

                                  await FileContentCache.instance.clearCache();

                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('File cache cleared'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                    setState(() {}); // Refresh cache stats
                                  }
                                },
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Clear Cache'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);

                                  // Trigger manual cleanup
                                  await FileCleanupService.instance
                                      .forceCleanup();

                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Storage cleanup completed'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    setState(() {}); // Refresh stats
                                  }
                                },
                                icon: const Icon(Icons.cleaning_services,
                                    size: 16),
                                label: const Text('Clean All'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // About Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'OllamaVerse v$_appVersion\n'
                        'A cross-platform GUI client for Ollama',
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          // Open URL in browser when tapped
                          // This would require url_launcher package
                          // For now, just show a message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'GitHub: https://github.com/MqtUA/OllamaVerse',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'GitHub: https://github.com/MqtUA/OllamaVerse',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHostField() {
    return TextField(
      controller: _hostController,
      decoration: const InputDecoration(
        labelText: 'Host',
        hintText: 'localhost',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPortField() {
    return TextField(
      controller: _portController,
      decoration: const InputDecoration(
        labelText: 'Port',
        hintText: '11434',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildAuthTokenField() {
    return TextField(
      controller: _authTokenController,
      decoration: InputDecoration(
        labelText: 'Auth Token (Optional)',
        hintText: 'Bearer token for authentication',
        border: const OutlineInputBorder(),
        helperText: 'Used only if Ollama is behind an authentication server',
        suffixIcon: IconButton(
          icon: Icon(_showAuthToken ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _showAuthToken = !_showAuthToken;
              if (!_showAuthToken) {
                _authTokenController.text = '••••••••••••••••';
              } else {
                _loadAuthToken();
              }
            });
          },
        ),
      ),
      obscureText: !_showAuthToken,
    );
  }

  Widget _buildTestConnectionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isTesting ? null : _saveAndCheckConnection,
        child: _isTesting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Test Connection'),
      ),
    );
  }

  // Helper method to build performance metric rows
  Widget _buildPerformanceRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isGood ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
