import '../utils/logger.dart';

/// Represents the capabilities of an Ollama model
class ModelCapabilities {
  final String modelName;
  final bool supportsVision; // Can process images
  final bool supportsText; // Can process text (all models)
  final bool supportsCode; // Optimized for code
  final bool supportsMultimodal; // Can process both text and images
  final List<String> supportedImageTypes;
  final int maxImageSize; // Maximum image size in MB
  final String? description;

  const ModelCapabilities({
    required this.modelName,
    required this.supportsVision,
    required this.supportsText,
    required this.supportsCode,
    required this.supportsMultimodal,
    required this.supportedImageTypes,
    required this.maxImageSize,
    this.description,
  });

  /// Create capabilities for a text-only model
  factory ModelCapabilities.textOnly(String modelName,
      {String? description, bool supportsCode = false}) {
    return ModelCapabilities(
      modelName: modelName,
      supportsVision: false,
      supportsText: true,
      supportsCode: supportsCode,
      supportsMultimodal: false,
      supportedImageTypes: [],
      maxImageSize: 0,
      description: description,
    );
  }

  /// Create capabilities for a vision model
  factory ModelCapabilities.vision(
    String modelName, {
    String? description,
    List<String>? imageTypes,
    int maxImageSizeMB = 10,
  }) {
    return ModelCapabilities(
      modelName: modelName,
      supportsVision: true,
      supportsText: true,
      supportsCode: false,
      supportsMultimodal: true,
      supportedImageTypes:
          imageTypes ?? ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      maxImageSize: maxImageSizeMB,
      description: description,
    );
  }

  @override
  String toString() {
    final capabilities = <String>[];
    if (supportsText) capabilities.add('text');
    if (supportsVision) capabilities.add('vision');
    if (supportsCode) capabilities.add('code');
    return 'ModelCapabilities($modelName: ${capabilities.join(', ')})';
  }
}

/// Service for detecting and managing model capabilities
class ModelCapabilityService {
  // Cache for model capabilities to avoid repeated lookups
  static final Map<String, ModelCapabilities> _capabilityCache = {};

  // Clear cache on service startup to apply new detection logic
  static bool _cacheCleared = false;

  // Known vision model patterns (models that support image inputs)
  static const List<String> _visionModelPatterns = [
    'llava', // LLaVA models
    'bakllava', // BakLLaVA models
    'moondream', // Moondream vision models
    'cogvlm', // CogVLM models
    'mini-cpm', // MiniCPM-V models
    'llava-llama3', // LLaVA Llama3 variants
    'llava-phi3', // LLaVA Phi3 variants
    'minicpm-v', // MiniCPM-V variants
  ];

  // Known code-specialized models
  static const List<String> _codeModelPatterns = [
    'codellama', // Code Llama models
    'starcoder', // StarCoder models
    'codegeex', // CodeGeeX models
    'deepseek-coder', // DeepSeek Coder
    'magicoder', // MagiCoder models
    'phind-codellama', // Phind CodeLlama
    'code-', // Generic code prefix
  ];

  /// Get capabilities for a specific model
  static ModelCapabilities getModelCapabilities(String modelName) {
    // Clear cache once to apply new detection logic
    if (!_cacheCleared) {
      _capabilityCache.clear();
      _cacheCleared = true;
      AppLogger.info(
          'Cleared model capability cache for updated detection logic');
    }

    // Check cache first
    if (_capabilityCache.containsKey(modelName)) {
      return _capabilityCache[modelName]!;
    }

    // Determine capabilities based on model name patterns
    final capabilities = _detectCapabilities(modelName);

    // Cache the result
    _capabilityCache[modelName] = capabilities;

    AppLogger.info('Detected capabilities for $modelName: $capabilities');
    return capabilities;
  }

  /// Detect capabilities based on model name patterns
  static ModelCapabilities _detectCapabilities(String modelName) {
    final lowerName = modelName.toLowerCase();

    // Assume all models support vision by default
    // If the model doesn't actually support vision, Ollama will return an error
    bool isVisionModel = true;
    bool isCodeModel = false;
    String description =
        'Vision-language model capable of processing images and text';

    // Check for known vision models to provide better descriptions
    for (final pattern in _visionModelPatterns) {
      if (lowerName.contains(pattern.toLowerCase())) {
        description = _getVisionModelDescription(lowerName);
        break;
      }
    }

    // Check for code models (they can also be vision models)
    for (final pattern in _codeModelPatterns) {
      if (lowerName.contains(pattern.toLowerCase())) {
        isCodeModel = true;
        description =
            '${_getCodeModelDescription(lowerName)} with vision capabilities';
        break;
      }
    }

    // Create vision model capabilities for all models
    return ModelCapabilities(
      modelName: modelName,
      supportsVision: isVisionModel,
      supportsText: true,
      supportsCode: isCodeModel,
      supportsMultimodal: isVisionModel,
      supportedImageTypes: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      maxImageSize: 10,
      description: description,
    );
  }

  /// Get description for vision models
  static String _getVisionModelDescription(String lowerName) {
    if (lowerName.contains('llava')) {
      return 'Vision-language model that can analyze images and answer questions about them';
    } else if (lowerName.contains('bakllava')) {
      return 'Vision model optimized for visual understanding and reasoning';
    } else if (lowerName.contains('moondream')) {
      return 'Compact vision model for image analysis and description';
    } else if (lowerName.contains('cogvlm')) {
      return 'Advanced vision-language model with strong multimodal capabilities';
    } else if (lowerName.contains('minicpm') ||
        lowerName.contains('mini-cpm')) {
      return 'Efficient vision model with good performance on mobile devices';
    } else {
      return 'Vision-language model capable of processing images and text';
    }
  }

  /// Get description for code models
  static String _getCodeModelDescription(String lowerName) {
    if (lowerName.contains('codellama')) {
      return 'Specialized model for code generation, analysis, and programming tasks';
    } else if (lowerName.contains('starcoder')) {
      return 'Code generation model trained on diverse programming languages';
    } else if (lowerName.contains('deepseek')) {
      return 'Advanced coding model with strong algorithmic problem-solving abilities';
    } else if (lowerName.contains('phind')) {
      return 'Code model optimized for developer productivity and problem-solving';
    } else {
      return 'Specialized model for programming and code-related tasks';
    }
  }

  /// Check if a model supports vision/image processing
  static bool supportsVision(String modelName) {
    return getModelCapabilities(modelName).supportsVision;
  }

  /// Check if a model is optimized for code
  static bool supportsCode(String modelName) {
    return getModelCapabilities(modelName).supportsCode;
  }

  /// Check if a model supports multimodal inputs
  static bool supportsMultimodal(String modelName) {
    return getModelCapabilities(modelName).supportsMultimodal;
  }

  /// Get all models that support vision from a list
  static List<String> getVisionModels(List<String> availableModels) {
    return availableModels.where((model) => supportsVision(model)).toList();
  }

  /// Get all models that support code from a list
  static List<String> getCodeModels(List<String> availableModels) {
    return availableModels.where((model) => supportsCode(model)).toList();
  }

  /// Get the best model for a specific task
  static String? getBestModelForTask(
    List<String> availableModels,
    ModelTask task,
  ) {
    switch (task) {
      case ModelTask.vision:
        final visionModels = getVisionModels(availableModels);
        return visionModels.isNotEmpty ? visionModels.first : null;

      case ModelTask.code:
        final codeModels = getCodeModels(availableModels);
        return codeModels.isNotEmpty ? codeModels.first : null;

      case ModelTask.text:
        return availableModels.isNotEmpty ? availableModels.first : null;
    }
  }

  /// Clear the capability cache (useful for testing or model updates)
  static void clearCache() {
    _capabilityCache.clear();
    AppLogger.info('Model capability cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final visionCount =
        _capabilityCache.values.where((cap) => cap.supportsVision).length;
    final codeCount =
        _capabilityCache.values.where((cap) => cap.supportsCode).length;
    final textCount = _capabilityCache.values
        .where((cap) =>
            cap.supportsText && !cap.supportsVision && !cap.supportsCode)
        .length;

    return {
      'totalCached': _capabilityCache.length,
      'visionModels': visionCount,
      'codeModels': codeCount,
      'textModels': textCount,
    };
  }

  /// Get all cached capabilities for debugging
  static Map<String, ModelCapabilities> getAllCachedCapabilities() {
    return Map.unmodifiable(_capabilityCache);
  }

  /// Preload capabilities for a list of models
  static void preloadCapabilities(List<String> modelNames) {
    for (final modelName in modelNames) {
      getModelCapabilities(modelName);
    }
    AppLogger.info('Preloaded capabilities for ${modelNames.length} models');
  }

  /// Get supported image formats for a vision model
  static List<String> getSupportedImageFormats(String modelName) {
    final capabilities = getModelCapabilities(modelName);
    return capabilities.supportedImageTypes;
  }

  /// Check if a specific image format is supported by a model
  static bool supportsImageFormat(String modelName, String imageExtension) {
    final supportedFormats = getSupportedImageFormats(modelName);
    return supportedFormats.contains(imageExtension.toLowerCase());
  }
}

/// Enum for different model tasks
enum ModelTask {
  vision, // Image analysis and understanding
  code, // Programming and code-related tasks
  text, // General text processing
}
