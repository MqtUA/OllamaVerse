import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late double _fontSize;
  late bool _darkMode;
  late bool _showLiveResponse;
  late int _contextLength;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    _hostController = TextEditingController(text: settings.ollamaHost);
    _portController = TextEditingController(text: settings.ollamaPort.toString());
    _authTokenController = TextEditingController(text: settings.authToken);
    _fontSize = settings.fontSize;
    _darkMode = settings.darkMode;
    _showLiveResponse = settings.showLiveResponse;
    _contextLength = settings.contextLength;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }
  
  // Handle saving settings and checking connection
  Future<void> _saveAndCheckConnection() async {
    // Set loading state
    setState(() {
      _isTesting = true;
    });
    
    try {
      final host = _hostController.text;
      final port = int.tryParse(_portController.text) ?? 11434;
      final authToken = _authTokenController.text;
      
      // Get providers
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Update settings
      await settingsProvider.updateSettings(
        ollamaHost: host,
        ollamaPort: port,
        authToken: authToken,
      );
      
      // Test connection - must check mounted after each async operation
      if (!mounted) return;
      
      final ollamaService = settingsProvider.getOllamaService();
      final isConnected = await ollamaService.testConnection();
      
      // Must check mounted again after the async operation
      if (!mounted) return;
      
      if (isConnected) {
        // Connection successful, refresh models
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.refreshModels();
        
        // Must check mounted again
        if (!mounted) return;
        
        // Show success message
        _showSuccessMessage();
      } else {
        // Show connection failed dialog
        _showConnectionFailedDialog();
      }
    } catch (e) {
      // Show error dialog if still mounted
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      // Reset loading state if still mounted
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
        backgroundColor: Colors.green
      ),
    );
  }
  
  // Show connection failed dialog
  void _showConnectionFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Failed'),
        content: const Text('Could not connect to the Ollama server. Please check your settings and ensure the server is running.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Ollama Server Settings Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Ollama Host',
                          hintText: 'e.g., 127.0.0.1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Ollama Port',
                          hintText: 'e.g., 11434',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _authTokenController,
                        decoration: const InputDecoration(
                          labelText: 'Auth Token (Optional)',
                          hintText: 'Bearer token for authentication',
                          border: OutlineInputBorder(),
                          helperText: 'Used only if Ollama is behind an authentication server',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isTesting 
                            ? null 
                            : () {
                                // Use a separate method to handle async operations
                                _saveAndCheckConnection();
                              },
                          child: _isTesting 
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Testing connection...'),
                                ],
                              )
                            : const Text('Save and check connection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // App Appearance Settings Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                                settingsProvider.updateSettings(fontSize: value);
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
                        subtitle: const Text('See responses as they are generated'),
                        value: _showLiveResponse,
                        onChanged: (value) {
                          setState(() {
                            _showLiveResponse = value;
                          });
                          settingsProvider.updateSettings(showLiveResponse: value);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Context Length'),
                        subtitle: const Text('Maximum token context window (default: 4096)'),
                        trailing: DropdownButton<int>(
                          value: _contextLength,
                          items: [2048, 4096, 8192, 16384, 32768].map((int value) {
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
                              settingsProvider.updateSettings(contextLength: newValue);
                            }
                          },
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'OllamaVerse v1.0.0\n'
                        'A cross-platform GUI client for Ollama\n'
                        'Works on Windows and Android',
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
}
