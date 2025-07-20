import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/generation_settings.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';

/// Modal dialog for configuring per-chat generation settings
class ChatGenerationSettingsDialog extends StatefulWidget {
  final Chat chat;

  const ChatGenerationSettingsDialog({
    super.key,
    required this.chat,
  });

  @override
  State<ChatGenerationSettingsDialog> createState() => _ChatGenerationSettingsDialogState();
}

class _ChatGenerationSettingsDialogState extends State<ChatGenerationSettingsDialog> {
  late bool _useCustomSettings;
  late GenerationSettings _currentSettings;
  late GenerationSettings _globalSettings;
  
  late TextEditingController _topKController;
  late TextEditingController _maxTokensController;
  late TextEditingController _numThreadController;

  @override
  void initState() {
    super.initState();
    
    final settingsProvider = context.read<SettingsProvider>();
    _globalSettings = settingsProvider.settings.generationSettings;
    
    _useCustomSettings = widget.chat.hasCustomGenerationSettings;
    _currentSettings = widget.chat.customGenerationSettings ?? _globalSettings;
    
    _topKController = TextEditingController(text: _currentSettings.topK.toString());
    _maxTokensController = TextEditingController(
      text: _currentSettings.maxTokens == -1 ? '' : _currentSettings.maxTokens.toString()
    );
    _numThreadController = TextEditingController(text: _currentSettings.numThread.toString());
  }

  @override
  void dispose() {
    _topKController.dispose();
    _maxTokensController.dispose();
    _numThreadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 600 ? 600 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generation Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Configure settings for this chat',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom settings toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Use Custom Settings',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _useCustomSettings
                                            ? 'This chat will use custom generation settings'
                                            : 'This chat will use global generation settings',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _useCustomSettings,
                                  onChanged: (value) {
                                    setState(() {
                                      _useCustomSettings = value;
                                      if (!value) {
                                        // Reset to global settings
                                        _currentSettings = _globalSettings;
                                        _updateControllers();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            
                            if (!_useCustomSettings) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Using global settings. Enable custom settings to override for this chat.',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Settings controls (only shown when custom settings are enabled)
                    if (_useCustomSettings) ...[
                      _buildSettingsCard(),
                    ] else ...[
                      _buildGlobalSettingsPreview(),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_useCustomSettings) ...[
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentSettings = _globalSettings;
                          _updateControllers();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to Global'),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    final errors = _currentSettings.getValidationErrors();
    final warnings = _currentSettings.getWarnings();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Generation Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'These settings will override the global defaults for this chat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            
            // Show validation errors if any
            if (errors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Validation Errors',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...errors.map((error) => Text(
                      '• $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11,
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Show warnings if any
            if (warnings.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Performance Warnings',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...warnings.map((warning) => Text(
                      '• $warning',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 11,
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Settings controls in responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth <= 500;
                
                if (isCompact) {
                  // Compact layout - single column
                  return Column(
                    children: [
                      _buildTemperatureSlider(),
                      const SizedBox(height: 12),
                      _buildTopPSlider(),
                      const SizedBox(height: 12),
                      _buildTopKField(),
                      const SizedBox(height: 12),
                      _buildRepeatPenaltySlider(),
                      const SizedBox(height: 12),
                      _buildMaxTokensField(),
                      const SizedBox(height: 12),
                      _buildNumThreadField(),
                    ],
                  );
                } else {
                  // Wide layout - two columns
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTemperatureSlider()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTopPSlider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTopKField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildRepeatPenaltySlider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildMaxTokensField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildNumThreadField()),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSettingsPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Global Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This chat is using the global generation settings',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            
            // Preview of global settings
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildSettingChip('Temperature', _globalSettings.temperature.toStringAsFixed(2)),
                _buildSettingChip('Top P', _globalSettings.topP.toStringAsFixed(2)),
                _buildSettingChip('Top K', _globalSettings.topK.toString()),
                _buildSettingChip('Repeat Penalty', _globalSettings.repeatPenalty.toStringAsFixed(2)),
                _buildSettingChip('Max Tokens', _globalSettings.maxTokens == -1 ? 'Unlimited' : _globalSettings.maxTokens.toString()),
                _buildSettingChip('Threads', _globalSettings.numThread.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureSlider() {
    return _buildSliderSetting(
      title: 'Temperature',
      description: 'Controls randomness',
      helpText: 'Higher values make responses more creative and varied',
      value: _currentSettings.temperature,
      min: 0.0,
      max: 2.0,
      divisions: 40,
      onChanged: (value) => _updateSetting((s) => s.copyWith(temperature: value)),
    );
  }

  Widget _buildTopPSlider() {
    return _buildSliderSetting(
      title: 'Top P',
      description: 'Controls diversity',
      helpText: 'Lower values focus on most likely words',
      value: _currentSettings.topP,
      min: 0.0,
      max: 1.0,
      divisions: 20,
      onChanged: (value) => _updateSetting((s) => s.copyWith(topP: value)),
    );
  }

  Widget _buildRepeatPenaltySlider() {
    return _buildSliderSetting(
      title: 'Repeat Penalty',
      description: 'Reduces repetition',
      helpText: 'Values above 1.0 reduce repetitive responses',
      value: _currentSettings.repeatPenalty,
      min: 0.5,
      max: 2.0,
      divisions: 30,
      onChanged: (value) => _updateSetting((s) => s.copyWith(repeatPenalty: value)),
    );
  }

  Widget _buildTopKField() {
    return _buildNumberField(
      title: 'Top K',
      description: 'Vocabulary limit',
      helpText: 'Only consider the K most likely next words',
      controller: _topKController,
      value: _currentSettings.topK,
      min: 1,
      max: 100,
      onChanged: (value) => _updateSetting((s) => s.copyWith(topK: value)),
    );
  }

  Widget _buildMaxTokensField() {
    return _buildNumberField(
      title: 'Max Tokens',
      description: 'Response length limit',
      helpText: 'Maximum number of tokens in response',
      controller: _maxTokensController,
      value: _currentSettings.maxTokens == -1 ? null : _currentSettings.maxTokens,
      min: 1,
      max: 4096,
      allowEmpty: true,
      emptyValue: -1,
      onChanged: (value) => _updateSetting((s) => s.copyWith(maxTokens: value ?? -1)),
    );
  }

  Widget _buildNumThreadField() {
    return _buildNumberField(
      title: 'Threads',
      description: 'Processing threads',
      helpText: 'Number of threads used for generation',
      controller: _numThreadController,
      value: _currentSettings.numThread,
      min: 1,
      max: 16,
      onChanged: (value) => _updateSetting((s) => s.copyWith(numThread: value)),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String description,
    required String helpText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: helpText,
              child: Icon(
                Icons.help_outline,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 50,
              child: Text(
                value.toStringAsFixed(value < 1 ? 2 : 1),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String title,
    required String description,
    required String helpText,
    required TextEditingController controller,
    required int? value,
    required int min,
    required int max,
    required ValueChanged<int?> onChanged,
    bool allowEmpty = false,
    int? emptyValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: helpText,
              child: Icon(
                Icons.help_outline,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: allowEmpty ? 'Empty = unlimited' : null,
              hintStyle: const TextStyle(fontSize: 11),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              errorText: _getFieldError(value, min, max, allowEmpty),
              errorStyle: const TextStyle(fontSize: 10),
            ),
            onChanged: (text) {
              if (allowEmpty && text.isEmpty) {
                onChanged(emptyValue);
                return;
              }
              
              final parsedValue = int.tryParse(text);
              if (parsedValue != null) {
                onChanged(parsedValue);
              }
            },
          ),
        ),
      ],
    );
  }

  String? _getFieldError(int? value, int min, int max, bool allowEmpty) {
    if (value == null) {
      return allowEmpty ? null : 'Required';
    }
    
    if (value < min || value > max) {
      return 'Must be $min-$max';
    }
    
    return null;
  }

  void _updateSetting(GenerationSettings Function(GenerationSettings) updater) {
    setState(() {
      _currentSettings = updater(_currentSettings);
      _updateControllers();
    });
  }

  void _updateControllers() {
    _topKController.text = _currentSettings.topK.toString();
    _maxTokensController.text = _currentSettings.maxTokens == -1 ? '' : _currentSettings.maxTokens.toString();
    _numThreadController.text = _currentSettings.numThread.toString();
  }

  void _saveSettings() {
    final chatProvider = context.read<ChatProvider>();
    
    // Validate settings before saving
    if (!_currentSettings.isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix validation errors before saving'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    
    // Update chat with new settings
    chatProvider.updateChatGenerationSettings(
      widget.chat.id,
      _useCustomSettings ? _currentSettings : null,
    );
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useCustomSettings 
            ? 'Custom generation settings saved for this chat'
            : 'Chat reset to use global generation settings'
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    
    Navigator.of(context).pop();
  }


}