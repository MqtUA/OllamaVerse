import 'dart:collection';
import '../models/generation_settings.dart';
import '../models/chat.dart';
import '../models/app_settings.dart';
import 'performance_monitor.dart';

/// Optimized service for resolving generation settings with caching and performance monitoring
class OptimizedGenerationSettingsService {
  // Singleton pattern for global access
  static final OptimizedGenerationSettingsService _instance = OptimizedGenerationSettingsService._internal();
  factory OptimizedGenerationSettingsService() => _instance;
  OptimizedGenerationSettingsService._internal();

  // Performance monitoring
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // Caching for performance optimization
  final LRUCache<String, GenerationSettings> _settingsCache = LRUCache<String, GenerationSettings>(100);
  final LRUCache<String, Map<String, dynamic>> _optionsCache = LRUCache<String, Map<String, dynamic>>(200);
  final LRUCache<String, List<String>> _validationCache = LRUCache<String, List<String>>(50);
  
  // Cache for default settings to avoid repeated object creation
  GenerationSettings? _cachedDefaults;
  
  /// Initialize the service
  void initialize() {
    _performanceMonitor.initialize();
  }

  /// Dispose of the service
  void dispose() {
    _performanceMonitor.dispose();
    _settingsCache.clear();
    _optionsCache.clear();
    _validationCache.clear();
  }

  /// Resolves the effective generation settings for a chat with caching
  GenerationSettings getEffectiveSettings({
    required Chat? chat,
    required AppSettings globalSettings,
  }) {
    final timer = _performanceMonitor.startTimer('settings_resolution');
    
    try {
      // Create cache key
      final cacheKey = _createSettingsCacheKey(chat, globalSettings);
      
      // Check cache first
      final cached = _settingsCache.get(cacheKey);
      if (cached != null) {
        return cached;
      }
      
      // Resolve settings
      GenerationSettings result;
      if (chat?.hasCustomGenerationSettings == true) {
        result = chat!.customGenerationSettings!;
      } else {
        result = globalSettings.generationSettings;
      }
      
      // Cache the result
      _settingsCache.put(cacheKey, result);
      
      return result;
    } finally {
      timer.stop();
    }
  }

  /// Builds Ollama API options with caching and optimization
  Map<String, dynamic> buildOllamaOptions({
    required GenerationSettings settings,
    int? contextLength,
    bool isStreaming = false,
  }) {
    final timer = _performanceMonitor.startTimer('api_options_build');
    
    try {
      // Create cache key
      final cacheKey = _createOptionsCacheKey(settings, contextLength, isStreaming);
      
      // Check cache first
      final cached = _optionsCache.get(cacheKey);
      if (cached != null) {
        return Map<String, dynamic>.from(cached);
      }
      
      // Build options efficiently
      final options = _buildOptionsOptimized(settings, contextLength, isStreaming);
      
      // Cache the result
      _optionsCache.put(cacheKey, options);
      
      return Map<String, dynamic>.from(options);
    } finally {
      timer.stop();
    }
  }

  /// Validates settings with caching
  bool validateSettings(GenerationSettings settings) {
    final timer = _performanceMonitor.startTimer('settings_validation');
    
    try {
      final errors = getValidationErrors(settings);
      return errors.isEmpty;
    } finally {
      timer.stop();
    }
  }

  /// Gets validation errors with caching
  List<String> getValidationErrors(GenerationSettings settings) {
    final cacheKey = settings.hashCode.toString();
    
    // Check cache first
    final cached = _validationCache.get(cacheKey);
    if (cached != null) {
      return List<String>.from(cached);
    }
    
    // Validate settings
    final errors = settings.getValidationErrors();
    
    // Cache the result
    _validationCache.put(cacheKey, errors);
    
    return List<String>.from(errors);
  }

  /// Gets recommendations with performance optimization
  List<String> getRecommendations(GenerationSettings settings) {
    final timer = _performanceMonitor.startTimer('get_recommendations');
    
    try {
      final recommendations = <String>[];
      
      // Add validation errors first (these are critical)
      final errors = getValidationErrors(settings);
      for (final error in errors) {
        recommendations.add('ERROR: $error');
      }
      
      // Add performance warnings (cached)
      final warnings = _getCachedWarnings(settings);
      for (final warning in warnings) {
        recommendations.add('WARNING: $warning');
      }
      
      // Add positive recommendations for good settings
      if (errors.isEmpty && warnings.isEmpty) {
        recommendations.add('Settings look good! These values should work well for most use cases.');
      }
      
      // Add specific recommendations based on settings combinations
      _addCombinationRecommendations(settings, recommendations);
      
      return recommendations;
    } finally {
      timer.stop();
    }
  }

  /// Creates a safe, validated version of settings with caching
  GenerationSettings createSafeSettings(GenerationSettings settings) {
    final timer = _performanceMonitor.startTimer('create_safe_settings');
    
    try {
      // If settings are already valid, return as-is
      if (validateSettings(settings)) {
        return settings;
      }
      
      // Create validated settings
      return GenerationSettings.validated(
        temperature: settings.temperature,
        topP: settings.topP,
        topK: settings.topK,
        repeatPenalty: settings.repeatPenalty,
        maxTokens: settings.maxTokens,
        numThread: settings.numThread,
      );
    } finally {
      timer.stop();
    }
  }

  /// Compares settings efficiently
  Map<String, dynamic> compareSettings(
    GenerationSettings settings1,
    GenerationSettings settings2,
  ) {
    final timer = _performanceMonitor.startTimer('compare_settings');
    
    try {
      final differences = <String, dynamic>{};
      
      // Use efficient comparison
      if (settings1.temperature != settings2.temperature) {
        differences['temperature'] = {
          'from': settings1.temperature,
          'to': settings2.temperature,
        };
      }
      
      if (settings1.topP != settings2.topP) {
        differences['topP'] = {
          'from': settings1.topP,
          'to': settings2.topP,
        };
      }
      
      if (settings1.topK != settings2.topK) {
        differences['topK'] = {
          'from': settings1.topK,
          'to': settings2.topK,
        };
      }
      
      if (settings1.repeatPenalty != settings2.repeatPenalty) {
        differences['repeatPenalty'] = {
          'from': settings1.repeatPenalty,
          'to': settings2.repeatPenalty,
        };
      }
      
      if (settings1.maxTokens != settings2.maxTokens) {
        differences['maxTokens'] = {
          'from': settings1.maxTokens,
          'to': settings2.maxTokens,
        };
      }
      
      if (settings1.numThread != settings2.numThread) {
        differences['numThread'] = {
          'from': settings1.numThread,
          'to': settings2.numThread,
        };
      }
      
      return differences;
    } finally {
      timer.stop();
    }
  }

  /// Gets settings summary efficiently
  String getSettingsSummary(GenerationSettings settings) {
    // Use string buffer for efficient concatenation
    final buffer = StringBuffer();
    
    buffer.write('Temp: ${settings.temperature.toStringAsFixed(1)}');
    buffer.write(' | Top-P: ${settings.topP.toStringAsFixed(2)}');
    buffer.write(' | Top-K: ${settings.topK}');
    buffer.write(' | Repeat: ${settings.repeatPenalty.toStringAsFixed(1)}');
    
    if (settings.maxTokens == -1) {
      buffer.write(' | Tokens: Unlimited');
    } else {
      buffer.write(' | Tokens: ${settings.maxTokens}');
    }
    
    buffer.write(' | Threads: ${settings.numThread}');
    
    return buffer.toString();
  }

  /// Determines if settings are extreme efficiently
  bool areSettingsExtreme(GenerationSettings settings) {
    return settings.temperature > 1.5 ||
           settings.temperature < 0.1 ||
           settings.topP < 0.1 ||
           settings.topK < 5 ||
           settings.repeatPenalty > 1.5 ||
           (settings.maxTokens > 0 && settings.maxTokens < 50) ||
           settings.numThread > 8;
  }

  /// Gets default settings with caching
  GenerationSettings getDefaultSettings() {
    return _cachedDefaults ??= GenerationSettings.defaults();
  }

  /// Gets performance report
  PerformanceReport getPerformanceReport() {
    return _performanceMonitor.generateReport();
  }

  /// Clears all caches (useful for memory management)
  void clearCaches() {
    _settingsCache.clear();
    _optionsCache.clear();
    _validationCache.clear();
  }

  /// Gets cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'settings_cache': {
        'size': _settingsCache.length,
        'capacity': _settingsCache.capacity,
        'hit_rate': _settingsCache.hitRate,
      },
      'options_cache': {
        'size': _optionsCache.length,
        'capacity': _optionsCache.capacity,
        'hit_rate': _optionsCache.hitRate,
      },
      'validation_cache': {
        'size': _validationCache.length,
        'capacity': _validationCache.capacity,
        'hit_rate': _validationCache.hitRate,
      },
    };
  }

  // Private helper methods

  String _createSettingsCacheKey(Chat? chat, AppSettings globalSettings) {
    if (chat?.hasCustomGenerationSettings == true) {
      return 'chat_${chat!.id}_${chat.customGenerationSettings.hashCode}';
    } else {
      return 'global_${globalSettings.generationSettings.hashCode}';
    }
  }

  String _createOptionsCacheKey(GenerationSettings settings, int? contextLength, bool isStreaming) {
    return '${settings.hashCode}_${contextLength ?? 'null'}_$isStreaming';
  }

  Map<String, dynamic> _buildOptionsOptimized(GenerationSettings settings, int? contextLength, bool isStreaming) {
    final defaults = getDefaultSettings();
    final options = <String, dynamic>{};

    // Only include non-default values
    if (settings.temperature != defaults.temperature) {
      options['temperature'] = settings.temperature;
    }
    
    if (settings.topP != defaults.topP) {
      options['top_p'] = settings.topP;
    }
    
    if (settings.topK != defaults.topK) {
      options['top_k'] = settings.topK;
    }
    
    if (settings.repeatPenalty != defaults.repeatPenalty) {
      options['repeat_penalty'] = settings.repeatPenalty;
    }
    
    if (settings.maxTokens != defaults.maxTokens && settings.maxTokens > 0) {
      options['num_predict'] = settings.maxTokens;
    }
    
    if (settings.numThread != defaults.numThread) {
      options['num_thread'] = settings.numThread;
    }

    // Add context length if provided and different from default
    if (contextLength != null && contextLength != 4096) {
      options['num_ctx'] = contextLength;
    }

    return options;
  }

  List<String> _getCachedWarnings(GenerationSettings settings) {
    // This could be cached too, but warnings are relatively quick to compute
    return settings.getWarnings();
  }

  void _addCombinationRecommendations(GenerationSettings settings, List<String> recommendations) {
    // Add specific recommendations based on settings combinations
    if (settings.temperature > 1.0 && settings.topP > 0.95) {
      recommendations.add('SUGGESTION: High temperature with high Top P may produce very unpredictable results. Consider lowering one of these values.');
    }
    
    if (settings.temperature < 0.3 && settings.topK < 10) {
      recommendations.add('SUGGESTION: Very conservative settings may produce repetitive responses. Consider increasing temperature or Top K for more variety.');
    }
    
    if (settings.maxTokens > 0 && settings.maxTokens < 100) {
      recommendations.add('SUGGESTION: Low max tokens may cut off responses mid-sentence. Consider increasing or setting to unlimited (-1).');
    }
  }
}

/// Simple LRU Cache implementation for performance optimization
class LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();
  int _hits = 0;
  int _misses = 0;

  LRUCache(this.capacity);

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
      _hits++;
      return value;
    }
    _misses++;
    return null;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  int get length => _cache.length;
  
  double get hitRate {
    final total = _hits + _misses;
    return total > 0 ? _hits / total : 0.0;
  }
}