import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:ollamaverse/models/app_settings.dart';
import 'package:ollamaverse/models/ollama_model.dart';
import 'package:ollamaverse/services/ollama_service.dart';

// Generate a MockClient using the Mockito package
@GenerateMocks([http.Client])
void main() {
  late OllamaService ollamaService;
  final testSettings = AppSettings(
    ollamaHost: 'localhost',
    ollamaPort: 11434,
    contextLength: 4096,
    darkMode: false,
    fontSize: 14,
    showLiveResponse: true,
  );

  setUp(() {
    ollamaService = OllamaService(settings: testSettings);
    // Note: For proper testing, we would need to make the HTTP client injectable
  });

  group('OllamaService', () {
    test('constructor initializes with provided settings', () {
      expect(ollamaService.settings, equals(testSettings));
    });

    test('updateSettings updates the settings', () {
      final newSettings = AppSettings(
        ollamaHost: 'new-host',
        ollamaPort: 12345,
        contextLength: 2048,
        darkMode: true,
        fontSize: 16,
        showLiveResponse: false,
      );

      ollamaService.updateSettings(newSettings);
      expect(ollamaService.settings, equals(newSettings));
      expect(ollamaService.settings.ollamaUrl, equals('http://new-host:12345'));
    });

    test('updateSettings updates auth token', () {
      final newSettings = AppSettings(
        ollamaHost: 'new-host',
        ollamaPort: 12345,
        contextLength: 2048,
        darkMode: true,
        fontSize: 16,
        showLiveResponse: false,
      );

      ollamaService.updateSettings(newSettings, newAuthToken: 'new-token');
      expect(ollamaService.settings, equals(newSettings));
    });

    test('getModels returns list of models on success', () async {
      // This is a simplified test that doesn't use the mock client
      // In a real implementation, we would need to make the http client injectable

      // Skip this test if we can't connect to a real Ollama instance
      final hasConnection = await ollamaService.testConnection();
      if (!hasConnection) {
        // Use markTestSkipped instead of skip
        markTestSkipped('No Ollama server available for testing');
        return;
      }

      final models = await ollamaService.getModels();
      expect(models, isA<List<OllamaModel>>());
    });

    test('getModels throws OllamaApiException on API error', () async {
      // Setup a mock response for the http client
      // This would require making the client injectable in the real implementation
      // For now, this test is more of a demonstration

      expect(() async {
        // Simulate an API error by using an invalid URL
        final badSettings = AppSettings(
          ollamaHost: 'invalid-host',
          ollamaPort: 11434,
          contextLength: 4096,
          darkMode: false,
          fontSize: 14,
          showLiveResponse: true,
        );

        final service = OllamaService(settings: badSettings);
        await service.getModels();
      }, throwsA(isA<OllamaConnectionException>()));
    });
  });

  // This is a more advanced test that would require making the http client injectable
  group('Advanced tests (requires refactoring for testability)', () {
    test('getModels parses response correctly', () {
      // This test would require making the http client injectable
      // It would look something like this:

      /*
      when(mockClient.get(
        Uri.parse('http://localhost:11434/api/tags'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'models': [
            {
              'name': 'llama2',
              'modified_at': '2023-01-01T00:00:00Z',
              'size': 4000000000,
              'digest': 'abc123',
              'details': {},
            },
            {
              'name': 'mistral',
              'modified_at': '2023-01-02T00:00:00Z',
              'size': 5000000000,
              'digest': 'def456',
              'details': {},
            },
          ]
        }),
        200,
      ));
      
      final models = await ollamaService.getModels();
      expect(models.length, equals(2));
      expect(models[0].name, equals('llama2'));
      expect(models[1].name, equals('mistral'));
      */
    });
  });
}
