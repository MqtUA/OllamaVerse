import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/generation_settings.dart';
import '../providers/settings_provider.dart';

/// Responsive widget for configuring global generation settings
class GenerationSettingsWidget extends StatefulWidget {
  const GenerationSettingsWidget({super.key});

  @override
  State<GenerationSettingsWidget> createState() => _GenerationSettingsWidgetState();
}

class _GenerationSettingsWidgetState extends State<GenerationSettingsWidget> {
  late TextEditingController _topKController;
  late TextEditingController _maxTokensController;
  late TextEditingController _numThreadController;
  
  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings.generationSettings;
    _topKController = TextEditingController(text: settings.topK.toString());
    _maxTokensController = TextEditingController(
      text: settings.maxTokens == -1 ? '' : settings.maxTokens.toString()
    );
    _numThreadController = TextEditingController(text: settings.numThread.toString());
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
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final settings = settingsProvider.settings.generationSettings;
        final errors = settings.getValidationErrors();
        final warnings = settings.getWarnings();
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generation Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure how the AI generates responses',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Validation Errors',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...errors.map((error) => Text(
                          '• $error',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Performance Warnings',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...warnings.map((warning) => Text(
                          '• $warning',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 12,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Responsive layout for settings controls
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth <= 600;
                    
                    if (isCompact) {
                      // Mobile layout - single column
                      return Column(
                        children: [
                          _buildTemperatureSlider(settings, settingsProvider),
                          const SizedBox(height: 16),
                          _buildTopPSlider(settings, settingsProvider),
                          const SizedBox(height: 16),
                          _buildTopKField(settings, settingsProvider),
                          const SizedBox(height: 16),
                          _buildRepeatPenaltySlider(settings, settingsProvider),
                          const SizedBox(height: 16),
                          _buildMaxTokensField(settings, settingsProvider),
                          const SizedBox(height: 16),
                          _buildNumThreadField(settings, settingsProvider),
                        ],
                      );
                    } else {
                      // Desktop layout - responsive grid
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildTemperatureSlider(settings, settingsProvider)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTopPSlider(settings, settingsProvider)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTopKField(settings, settingsProvider)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildRepeatPenaltySlider(settings, settingsProvider)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildMaxTokensField(settings, settingsProvider)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildNumThreadField(settings, settingsProvider)),
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
      },
    );
  }

  Widget _buildTemperatureSlider(GenerationSettings settings, SettingsProvider provider) {
    return _buildSliderSetting(
      title: 'Temperature',
      description: 'Controls randomness in responses',
      helpText: 'Higher values (0.8-1.2) make responses more creative and varied, '
          'while lower values (0.1-0.5) make them more focused and deterministic.',
      value: settings.temperature,
      min: 0.0,
      max: 2.0,
      divisions: 40,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(temperature: value),
      ),
    );
  }

  Widget _buildTopPSlider(GenerationSettings settings, SettingsProvider provider) {
    return _buildSliderSetting(
      title: 'Top P',
      description: 'Controls diversity of word choices',
      helpText: 'Nucleus sampling parameter. Lower values (0.1-0.5) focus on most likely words, '
          'higher values (0.8-0.95) allow more diverse vocabulary.',
      value: settings.topP,
      min: 0.0,
      max: 1.0,
      divisions: 20,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(topP: value),
      ),
    );
  }

  Widget _buildRepeatPenaltySlider(GenerationSettings settings, SettingsProvider provider) {
    return _buildSliderSetting(
      title: 'Repeat Penalty',
      description: 'Reduces repetitive responses',
      helpText: 'Penalizes repeated words and phrases. Values above 1.0 reduce repetition, '
          'while values below 1.0 allow more repetition.',
      value: settings.repeatPenalty,
      min: 0.5,
      max: 2.0,
      divisions: 30,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(repeatPenalty: value),
      ),
    );
  } 
 Widget _buildTopKField(GenerationSettings settings, SettingsProvider provider) {
    return _buildNumberField(
      title: 'Top K',
      description: 'Limits vocabulary to top K words',
      helpText: 'Only consider the K most likely next words. Lower values (5-20) '
          'make responses more focused, higher values (40-100) allow more variety.',
      controller: _topKController,
      value: settings.topK,
      min: 1,
      max: 100,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(topK: value),
      ),
    );
  }

  Widget _buildMaxTokensField(GenerationSettings settings, SettingsProvider provider) {
    return _buildNumberField(
      title: 'Max Tokens',
      description: 'Maximum response length',
      helpText: 'Maximum number of tokens in the response. Leave empty for unlimited. '
          'Typical values: 100-500 for short responses, 1000-2000 for longer ones.',
      controller: _maxTokensController,
      value: settings.maxTokens == -1 ? null : settings.maxTokens,
      min: 1,
      max: 4096,
      allowEmpty: true,
      emptyValue: -1,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(maxTokens: value ?? -1),
      ),
    );
  }

  Widget _buildNumThreadField(GenerationSettings settings, SettingsProvider provider) {
    return _buildNumberField(
      title: 'Threads',
      description: 'Number of processing threads',
      helpText: 'Number of threads used for generation. More threads can improve speed '
          'but may not help on all devices. Recommended: 2-8.',
      controller: _numThreadController,
      value: settings.numThread,
      min: 1,
      max: 16,
      onChanged: (value) => _updateGenerationSettings(
        provider,
        settings.copyWith(numThread: value),
      ),
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
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
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
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: Text(
                value.toStringAsFixed(value < 1 ? 2 : 1),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
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
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
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
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            decoration: InputDecoration(
              hintText: allowEmpty ? 'Empty for unlimited' : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              errorText: _getFieldError(value, min, max, allowEmpty),
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
      return 'Must be between $min and $max';
    }
    
    return null;
  }

  void _updateGenerationSettings(SettingsProvider provider, GenerationSettings newSettings) {
    // Update text controllers to reflect changes
    _topKController.text = newSettings.topK.toString();
    _maxTokensController.text = newSettings.maxTokens == -1 ? '' : newSettings.maxTokens.toString();
    _numThreadController.text = newSettings.numThread.toString();
    
    // Update settings
    provider.updateSettings(
      generationSettings: newSettings,
      validateSettings: true,
    );
  }
}