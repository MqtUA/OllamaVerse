import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/generation_settings.dart';

/// Small visual indicator that shows when a chat has custom generation settings
class GenerationSettingsIndicator extends StatelessWidget {
  final Chat chat;
  final GenerationSettings globalSettings;
  final VoidCallback? onTap;
  final bool compact;

  const GenerationSettingsIndicator({
    super.key,
    required this.chat,
    required this.globalSettings,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show indicator if chat has custom settings
    if (!chat.hasCustomGenerationSettings) {
      return const SizedBox.shrink();
    }

    final customSettings = chat.customGenerationSettings!;
    final settingsSummary = _buildSettingsSummary(customSettings);

    return Tooltip(
      message: 'Custom Generation Settings\n$settingsSummary',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 4 : 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: compact ? 14 : 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildSettingsSummary(GenerationSettings settings) {
    final differences = <String>[];
    
    // Compare with global settings and show only differences
    if (settings.temperature != globalSettings.temperature) {
      differences.add('Temperature: ${settings.temperature.toStringAsFixed(2)}');
    }
    
    if (settings.topP != globalSettings.topP) {
      differences.add('Top P: ${settings.topP.toStringAsFixed(2)}');
    }
    
    if (settings.topK != globalSettings.topK) {
      differences.add('Top K: ${settings.topK}');
    }
    
    if (settings.repeatPenalty != globalSettings.repeatPenalty) {
      differences.add('Repeat Penalty: ${settings.repeatPenalty.toStringAsFixed(2)}');
    }
    
    if (settings.maxTokens != globalSettings.maxTokens) {
      differences.add('Max Tokens: ${settings.maxTokens == -1 ? 'Unlimited' : settings.maxTokens.toString()}');
    }
    
    if (settings.numThread != globalSettings.numThread) {
      differences.add('Threads: ${settings.numThread}');
    }
    
    if (differences.isEmpty) {
      return 'Custom settings enabled (same as global)';
    }
    
    return differences.join('\n');
  }
}

/// Extended indicator that shows a badge with the number of custom settings
class GenerationSettingsBadge extends StatelessWidget {
  final Chat chat;
  final GenerationSettings globalSettings;
  final VoidCallback? onTap;

  const GenerationSettingsBadge({
    super.key,
    required this.chat,
    required this.globalSettings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only show badge if chat has custom settings
    if (!chat.hasCustomGenerationSettings) {
      return const SizedBox.shrink();
    }

    final customSettings = chat.customGenerationSettings!;
    final differenceCount = _countDifferences(customSettings);
    final settingsSummary = _buildDetailedSummary(customSettings);

    return Tooltip(
      message: 'Custom Generation Settings\n$settingsSummary',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 12,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                differenceCount.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countDifferences(GenerationSettings settings) {
    int count = 0;
    
    if (settings.temperature != globalSettings.temperature) count++;
    if (settings.topP != globalSettings.topP) count++;
    if (settings.topK != globalSettings.topK) count++;
    if (settings.repeatPenalty != globalSettings.repeatPenalty) count++;
    if (settings.maxTokens != globalSettings.maxTokens) count++;
    if (settings.numThread != globalSettings.numThread) count++;
    
    return count;
  }

  String _buildDetailedSummary(GenerationSettings settings) {
    final lines = <String>[];
    
    lines.add('Temperature: ${settings.temperature.toStringAsFixed(2)} ${_getDifferenceIndicator(settings.temperature, globalSettings.temperature)}');
    lines.add('Top P: ${settings.topP.toStringAsFixed(2)} ${_getDifferenceIndicator(settings.topP, globalSettings.topP)}');
    lines.add('Top K: ${settings.topK} ${_getDifferenceIndicator(settings.topK.toDouble(), globalSettings.topK.toDouble())}');
    lines.add('Repeat Penalty: ${settings.repeatPenalty.toStringAsFixed(2)} ${_getDifferenceIndicator(settings.repeatPenalty, globalSettings.repeatPenalty)}');
    lines.add('Max Tokens: ${settings.maxTokens == -1 ? 'Unlimited' : settings.maxTokens.toString()} ${_getDifferenceIndicator(settings.maxTokens.toDouble(), globalSettings.maxTokens.toDouble())}');
    lines.add('Threads: ${settings.numThread} ${_getDifferenceIndicator(settings.numThread.toDouble(), globalSettings.numThread.toDouble())}');
    
    return lines.join('\n');
  }

  String _getDifferenceIndicator(double current, double global) {
    if (current == global) return '(same)';
    if (current > global) return '(↑)';
    return '(↓)';
  }
}

/// Compact dot indicator for minimal UI space
class GenerationSettingsDot extends StatelessWidget {
  final Chat chat;
  final VoidCallback? onTap;

  const GenerationSettingsDot({
    super.key,
    required this.chat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only show dot if chat has custom settings
    if (!chat.hasCustomGenerationSettings) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'This chat has custom generation settings',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Animated indicator that pulses when settings are different
class AnimatedGenerationSettingsIndicator extends StatefulWidget {
  final Chat chat;
  final GenerationSettings globalSettings;
  final VoidCallback? onTap;
  final bool animate;

  const AnimatedGenerationSettingsIndicator({
    super.key,
    required this.chat,
    required this.globalSettings,
    this.onTap,
    this.animate = true,
  });

  @override
  State<AnimatedGenerationSettingsIndicator> createState() => _AnimatedGenerationSettingsIndicatorState();
}

class _AnimatedGenerationSettingsIndicatorState extends State<AnimatedGenerationSettingsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.animate && widget.chat.hasCustomGenerationSettings) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedGenerationSettingsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.animate && widget.chat.hasCustomGenerationSettings) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show indicator if chat has custom settings
    if (!widget.chat.hasCustomGenerationSettings) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.animate ? _opacityAnimation.value : 1.0,
            child: GenerationSettingsIndicator(
              chat: widget.chat,
              globalSettings: widget.globalSettings,
              onTap: widget.onTap,
              compact: true,
            ),
          ),
        );
      },
    );
  }
}