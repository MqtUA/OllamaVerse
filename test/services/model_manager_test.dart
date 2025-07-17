import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/services/ollama_service.dart';

// Simple mock implementations without mockito
class MockOllamaService implements OllamaService {
  List<String> modelsToReturn = [];
  bool connectionSuccess = true;
  Exception? exceptionToThrow;
  int getModelsCallCount = 0;
  
  @override
  Future<List<String>> getModels() async {
    getModelsCallCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return modelsToReturn;
  }
  
  @override
  Future<bool> testConnection() async {
    return connectionSuccess;
  }
  
  // Implement other required methods with minimal functionality
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsProvider implements ISettingsProvider {
  bool isLoadingValue = false;
  String lastSelectedModel = '';
  OllamaService ollamaService;
  int setLastSelectedModelCallCount = 0;
  String? lastSetModelName;
  
  MockSettingsProvider(this.ollamaService);
  
  @override
  bool get isLoading => isLoadingValue;
  
  @override
  OllamaService getOllamaService() => ollamaService;
  
  @override
  Future<String> getLastSelectedModel() async {
    return lastSelectedModel;
  }
  
  @override
  Future<void> setLastSelectedModel(String modelName) async {
    setLastSelectedModelCallCount++;
    lastSetModelName = modelName;
  }
}

void main() {
  group('ModelManager', () {
    late ModelManager modelManager;
    late MockSettingsProvider mockSettingsProvider;
    late MockOllamaService mockOllamaService;

    setUp(() {
      mockOllamaService = MockOllamaService();
      mockSettingsProvider = MockSettingsProvider(mockOllamaService);
      modelManager = ModelManager(settingsProvider: mockSettingsProvider);
    });

    test('should initialize successfully with last selected model', () async {
      mockSettingsProvider.lastSelectedModel = 'llama2';
      
      await modelManager.initialize();
      
      expect(modelManager.lastSelectedModel, equals('llama2'));
    });

    test('should load models successfully', () async {
      mockOllamaService.modelsToReturn = ['llama2', 'codellama', 'mistral'];
      
      final result = await modelManager.loadModels();
      
      expect(result, isTrue);
      expect(modelManager.availableModels, equals(['llama2', 'codellama', 'mistral']));
    });

    test('should handle connection error with retry', () async {
      mockOllamaService.exceptionToThrow = OllamaConnectionException('Connection failed');
      
      final result = await modelManager.loadModels();
      
      expect(result, isFalse);
      expect(modelManager.availableModels, isEmpty);
      expect(modelManager.lastError, contains('Cannot connect to Ollama server'));
      expect(mockOllamaService.getModelsCallCount, equals(3)); // Should retry 3 times
    });

    test('should set selected model and persist it', () async {
      await modelManager.setSelectedModel('llama2');
      
      expect(modelManager.lastSelectedModel, equals('llama2'));
      expect(mockSettingsProvider.setLastSelectedModelCallCount, equals(1));
      expect(mockSettingsProvider.lastSetModelName, equals('llama2'));
    });

    test('should get best available model', () async {
      mockOllamaService.modelsToReturn = ['llama2', 'codellama', 'mistral'];
      await modelManager.loadModels();
      await modelManager.setSelectedModel('codellama');
      
      expect(modelManager.getBestAvailableModel(), equals('codellama'));
    });

    test('should return unknown when no models available', () {
      expect(modelManager.getBestAvailableModel(), equals('unknown'));
    });

    test('should test connection successfully', () async {
      mockOllamaService.connectionSuccess = true;
      
      final result = await modelManager.testConnection();
      
      expect(result, isTrue);
    });

    test('should refresh models', () async {
      mockOllamaService.modelsToReturn = ['llama2'];
      
      final result = await modelManager.refreshModels();
      
      expect(result, isTrue);
      expect(modelManager.availableModels, equals(['llama2']));
    });
  });
}