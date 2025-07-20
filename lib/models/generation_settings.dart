/// Model for AI generation settings with validation and safe defaults
class GenerationSettings {
  final double temperature;
  final double topP;
  final int topK;
  final double repeatPenalty;
  final int maxTokens;
  final int numThread;

  const GenerationSettings({
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.repeatPenalty,
    required this.maxTokens,
    required this.numThread,
  });

  /// Creates GenerationSettings with safe default values
  factory GenerationSettings.defaults() {
    return const GenerationSettings(
      temperature: 0.7,
      topP: 0.9,
      topK: 40,
      repeatPenalty: 1.1,
      maxTokens: -1, // -1 means unlimited
      numThread: 4,
    );
  }

  /// Creates GenerationSettings from JSON with fallback to defaults
  factory GenerationSettings.fromJson(Map<String, dynamic> json) {
    final defaults = GenerationSettings.defaults();
    
    return GenerationSettings(
      temperature: _parseDouble(json['temperature']) ?? defaults.temperature,
      topP: _parseDouble(json['topP']) ?? defaults.topP,
      topK: _parseInt(json['topK']) ?? defaults.topK,
      repeatPenalty: _parseDouble(json['repeatPenalty']) ?? defaults.repeatPenalty,
      maxTokens: _parseInt(json['maxTokens']) ?? defaults.maxTokens,
      numThread: _parseInt(json['numThread']) ?? defaults.numThread,
    );
  }

  /// Helper method to safely parse double values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method to safely parse int values
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Converts to JSON map
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'repeatPenalty': repeatPenalty,
      'maxTokens': maxTokens,
      'numThread': numThread,
    };
  }

  /// Creates a copy with optional parameter overrides
  GenerationSettings copyWith({
    double? temperature,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? numThread,
  }) {
    return GenerationSettings(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      maxTokens: maxTokens ?? this.maxTokens,
      numThread: numThread ?? this.numThread,
    );
  }

  /// Validates all settings and returns true if valid
  bool isValid() {
    return getValidationErrors().isEmpty;
  }

  /// Returns list of validation error messages
  List<String> getValidationErrors() {
    final errors = <String>[];

    // Temperature validation (0.0 - 2.0)
    if (temperature < 0.0 || temperature > 2.0) {
      errors.add('Temperature must be between 0.0 and 2.0');
    }

    // Top P validation (0.0 - 1.0)
    if (topP < 0.0 || topP > 1.0) {
      errors.add('Top P must be between 0.0 and 1.0');
    }

    // Top K validation (1 - 100)
    if (topK < 1 || topK > 100) {
      errors.add('Top K must be between 1 and 100');
    }

    // Repeat Penalty validation (0.5 - 2.0)
    if (repeatPenalty < 0.5 || repeatPenalty > 2.0) {
      errors.add('Repeat Penalty must be between 0.5 and 2.0');
    }

    // Max Tokens validation (-1 for unlimited, or 1 - 4096)
    if (maxTokens != -1 && (maxTokens < 1 || maxTokens > 4096)) {
      errors.add('Max Tokens must be -1 (unlimited) or between 1 and 4096');
    }

    // Num Thread validation (1 - 16)
    if (numThread < 1 || numThread > 16) {
      errors.add('Number of threads must be between 1 and 16');
    }

    return errors;
  }

  /// Returns warnings for extreme values that might impact performance
  List<String> getWarnings() {
    final warnings = <String>[];

    if (temperature > 1.5) {
      warnings.add('High temperature (>${temperature.toStringAsFixed(1)}) may produce very random responses');
    }
    
    if (temperature < 0.1) {
      warnings.add('Very low temperature (<${temperature.toStringAsFixed(1)}) may produce repetitive responses');
    }

    if (topP < 0.1) {
      warnings.add('Very low Top P (<${topP.toStringAsFixed(1)}) may limit response diversity');
    }

    if (topK < 5) {
      warnings.add('Very low Top K (<$topK) may produce repetitive responses');
    }

    if (repeatPenalty > 1.5) {
      warnings.add('High repeat penalty (>${repeatPenalty.toStringAsFixed(1)}) may produce incoherent responses');
    }

    if (maxTokens > 0 && maxTokens < 50) {
      warnings.add('Very low max tokens (<$maxTokens) may cut off responses');
    }

    if (numThread > 8) {
      warnings.add('High thread count (>$numThread) may not improve performance on all devices');
    }

    return warnings;
  }

  /// Converts settings to Ollama API options format
  /// Only includes non-default values to avoid API conflicts
  Map<String, dynamic> toOllamaOptions() {
    final defaults = GenerationSettings.defaults();
    final options = <String, dynamic>{};

    if (temperature != defaults.temperature) {
      options['temperature'] = temperature;
    }
    
    if (topP != defaults.topP) {
      options['top_p'] = topP;
    }
    
    if (topK != defaults.topK) {
      options['top_k'] = topK;
    }
    
    if (repeatPenalty != defaults.repeatPenalty) {
      options['repeat_penalty'] = repeatPenalty;
    }
    
    if (maxTokens != defaults.maxTokens && maxTokens > 0) {
      options['num_predict'] = maxTokens;
    }
    
    if (numThread != defaults.numThread) {
      options['num_thread'] = numThread;
    }

    return options;
  }

  /// Creates a validated instance with safe fallbacks
  factory GenerationSettings.validated({
    double? temperature,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? numThread,
  }) {
    final defaults = GenerationSettings.defaults();
    
    return GenerationSettings(
      temperature: _clampDouble(temperature ?? defaults.temperature, 0.0, 2.0),
      topP: _clampDouble(topP ?? defaults.topP, 0.0, 1.0),
      topK: _clampInt(topK ?? defaults.topK, 1, 100),
      repeatPenalty: _clampDouble(repeatPenalty ?? defaults.repeatPenalty, 0.5, 2.0),
      maxTokens: _validateMaxTokens(maxTokens ?? defaults.maxTokens),
      numThread: _clampInt(numThread ?? defaults.numThread, 1, 16),
    );
  }

  /// Helper method to clamp double values within range
  static double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max);
  }

  /// Helper method to clamp int values within range
  static int _clampInt(int value, int min, int max) {
    return value.clamp(min, max);
  }

  /// Helper method to validate max tokens
  static int _validateMaxTokens(int value) {
    if (value == -1) return -1; // Unlimited is valid
    return value.clamp(1, 4096);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is GenerationSettings &&
        other.temperature == temperature &&
        other.topP == topP &&
        other.topK == topK &&
        other.repeatPenalty == repeatPenalty &&
        other.maxTokens == maxTokens &&
        other.numThread == numThread;
  }

  @override
  int get hashCode {
    return Object.hash(
      temperature,
      topP,
      topK,
      repeatPenalty,
      maxTokens,
      numThread,
    );
  }

  @override
  String toString() {
    return 'GenerationSettings('
        'temperature: $temperature, '
        'topP: $topP, '
        'topK: $topK, '
        'repeatPenalty: $repeatPenalty, '
        'maxTokens: $maxTokens, '
        'numThread: $numThread'
        ')';
  }
}