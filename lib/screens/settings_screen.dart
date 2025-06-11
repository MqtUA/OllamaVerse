import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';

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
  late double _fontSize;
  late bool _darkMode;
  late bool _showLiveResponse;
  late int _contextLength;
  bool _isTesting = false;
  String _appVersion = '';
  bool _showAuthToken = false;

  @override
  void initState() {
    super.initState();
    final settings =
        Provider.of<SettingsProvider>(context, listen: false).settings;
    _hostController = TextEditingController(text: settings.ollamaHost);
    _portController = TextEditingController(
      text: settings.ollamaPort.toString(),
    );
    _authTokenController = TextEditingController();
    _systemPromptController = TextEditingController(
      text: settings.systemPrompt,
    );
    _fontSize = settings.fontSize;
    _darkMode = settings.darkMode;
    _showLiveResponse = settings.showLiveResponse;
    _contextLength = settings.contextLength;

    // Load app version and auth token
    _loadAppVersion();
    _loadAuthToken();
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
      builder:
          (context) => AlertDialog(
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
      builder:
          (context) => AlertDialog(
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
                              value: _fontSize,
                              min: 12,
                              max: 24,
                              divisions: 12,
                              label: _fontSize.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() {
                                  _fontSize = value;
                                });
                              },
                              onChangeEnd: (value) {
                                settingsProvider.updateSettings(
                                  fontSize: value,
                                );
                              },
                            ),
                          ),
                          Text(_fontSize.toStringAsFixed(1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                          settingsProvider.updateSettings(darkMode: value);
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Show Live Response'),
                        subtitle: const Text(
                          'See responses as they are generated',
                        ),
                        value: _showLiveResponse,
                        onChanged: (value) {
                          setState(() {
                            _showLiveResponse = value;
                          });
                          settingsProvider.updateSettings(
                            showLiveResponse: value,
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Context Length'),
                        subtitle: const Text(
                          'Maximum token context window (default: 4096)',
                        ),
                        trailing: DropdownButton<int>(
                          value: _contextLength,
                          items:
                              [2048, 4096, 8192, 16384, 32768].map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _contextLength = newValue;
                              });
                              settingsProvider.updateSettings(
                                contextLength: newValue,
                              );
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
        child:
            _isTesting
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('Test Connection'),
      ),
    );
  }
}
