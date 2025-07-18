import 'package:flutter_test/flutter_test.dart';

import 'package:ollamaverse/services/chat_title_generator.dart';
import 'package:ollamaverse/services/ollama_service.dart';
import 'package:ollamaverse/services/model_manager.dart';
import 'package:ollamaverse/providers/settings_provider.dart';
import 'package:ollamaverse/models/app_settings.dart';

// Simple mock implementation without mockito
class MockOllamaService implements OllamaService {
  String? responseToReturn;
  Exception? exceptionToThrow;
  Duration? delayDuration;
  int generateResponseCallCount = 0;
  String? lastPrompt;
  String? lastModel;

  @override
  Future<String> generateResponseWithFiles(String prompt,
      {String? model,
      List<dynamic>? processedFiles,
      List<int>? context}) async {
    generateResponseCallCount++;
    lastPrompt = prompt;
    lastModel = model;

    if (delayDuration != null) {
      await Future.delayed(delayDuration!);
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return responseToReturn ?? 'Default Response';
  }

  // Implement other required methods with minimal functionality
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsProvider implements SettingsProvider {
  @override
  AppSettings get settings => AppSettings();
  
  @override
  bool get isLoading => false;
  
  @override
  OllamaService getOllamaService() => MockOllamaService();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatTitleGenerator', () {
    late ChatTitleGenerator titleGenerator;
    late MockOllamaService mockOllamaService;

    setUp(() {
      mockOllamaService = MockOllamaService();
      final mockSettingsProvider = MockSettingsProvider();
      final mockModelManager = ModelManager(settingsProvider: mockSettingsProvider);
      titleGenerator = ChatTitleGenerator(
        ollamaService: mockOllamaService,
        modelManager: mockModelManager,
      );
    });

    group('State Management', () {
      test('should track chat title generation state correctly', () {
        const chatId = 'test-chat-1';

        // Initially no chats generating titles
        expect(titleGenerator.isGeneratingTitle, false);
        expect(titleGenerator.isChatGeneratingTitle(chatId), false);
        expect(titleGenerator.chatsGeneratingTitle, isEmpty);
      });

      test('should clear title generation state for specific chat', () {
        const chatId = 'test-chat-1';

        // Manually add to generating set to test clearing
        titleGenerator.clearTitleGenerationState(chatId);

        expect(titleGenerator.isChatGeneratingTitle(chatId), false);
        expect(titleGenerator.isGeneratingTitle, false);
      });

      test('should clear all title generation state', () {
        titleGenerator.clearAllTitleGenerationState();

        expect(titleGenerator.isGeneratingTitle, false);
        expect(titleGenerator.chatsGeneratingTitle, isEmpty);
      });
    });

    group('Title Generation', () {
      test('should generate title successfully with normal response', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is machine learning?';
        const aiResponse =
            'Machine learning is a subset of artificial intelligence that enables computers to learn and make decisions from data without being explicitly programmed.';
        const modelName = 'llama2';
        const expectedTitle = 'Machine Learning Basics';

        mockOllamaService.responseToReturn = expectedTitle;

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, expectedTitle);
        expect(titleGenerator.isChatGeneratingTitle(chatId), false);
        expect(mockOllamaService.generateResponseCallCount, 1);
        expect(mockOllamaService.lastModel, modelName);
      });

      test('should handle timeout and return fallback title', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is machine learning?';
        const aiResponse = 'Machine learning is a subset of AI.';
        const modelName = 'llama2';

        // Simulate timeout by making the service hang
        mockOllamaService.delayDuration =
            const Duration(seconds: 35); // Longer than timeout
        mockOllamaService.responseToReturn = 'Should not reach here';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        // Should return fallback title
        expect(result, contains('machine'));
        expect(result, contains('learning'));
        expect(titleGenerator.isChatGeneratingTitle(chatId), false);
      },
          timeout:
              const Timeout(Duration(seconds: 40))); // Increase test timeout

      test('should handle service error and return fallback title', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is machine learning?';
        const aiResponse = 'Machine learning is a subset of AI.';
        const modelName = 'llama2';

        mockOllamaService.exceptionToThrow = Exception('Network error');

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        // Should return fallback title
        expect(result, contains('machine learning'));
        expect(titleGenerator.isChatGeneratingTitle(chatId), false);
      });

      test('should prevent duplicate title generation for same chat', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is machine learning?';
        const aiResponse = 'Machine learning is a subset of AI.';
        const modelName = 'llama2';

        // First call should proceed normally
        mockOllamaService.delayDuration = const Duration(milliseconds: 100);
        mockOllamaService.responseToReturn = 'Machine Learning Basics';

        // Start first generation (don't await)
        final future1 = titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        // Immediately start second generation for same chat
        final result2 = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        // Second call should return fallback immediately
        expect(result2, contains('machine learning'));

        // Wait for first call to complete
        final result1 = await future1;
        expect(result1, 'Machine Learning Basics');

        // Only one call to the service should have been made
        expect(mockOllamaService.generateResponseCallCount, 1);
      });
    });

    group('Message Processing', () {
      test('should handle long user messages by truncating', () async {
        const chatId = 'test-chat-1';
        final longUserMessage =
            'This is a very long user message that contains a lot of text and should be truncated for title generation. ' *
                    10 +
                'Please summarize this document.';
        const aiResponse = 'Here is a summary of the document.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'Document Summary Chat';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: longUserMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Document Summary Chat');
        // Verify that the prompt was truncated
        expect(mockOllamaService.lastPrompt!.length,
            lessThan(longUserMessage.length));
        expect(mockOllamaService.lastPrompt!,
            contains('Please summarize this document'));
      });

      test('should extract request patterns from long messages', () async {
        const chatId = 'test-chat-1';
        const longUserMessage =
            'Here is a very long document with lots of content that goes on and on with detailed information about various topics and subjects that are quite extensive and comprehensive in nature. Can you please analyze this document and provide insights?';
        const aiResponse = 'Here is the analysis.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'Document Analysis Chat';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: longUserMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Document Analysis Chat');
        // Should extract the request pattern
        expect(
            mockOllamaService.lastPrompt!,
            contains(
                'Can you please analyze this document and provide insights?'));
      });

      test('should handle thinking content in AI response', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is 2+2?';
        const aiResponseWithThinking = '''<thinking>
Let me calculate this simple math problem.
2 + 2 = 4
</thinking>

The answer is 4. This is a basic arithmetic operation where we add two numbers together.''';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'Math Problem Solution';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponseWithThinking,
          modelName: modelName,
        );

        expect(result, 'Math Problem Solution');
        // Should not contain thinking content in the prompt
        expect(mockOllamaService.lastPrompt!, isNot(contains('<thinking>')));
        expect(mockOllamaService.lastPrompt!, contains('The answer is 4'));
      });
    });

    group('Title Cleaning', () {
      test('should clean title response properly', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is AI?';
        const aiResponse = 'AI is artificial intelligence.';
        const modelName = 'llama2';
        const dirtyTitle = '"Title: Machine Learning Discussion"';

        mockOllamaService.responseToReturn = dirtyTitle;

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Machine Learning Discussion');
        expect(result, isNot(contains('"')));
        expect(result, isNot(contains('Title:')));
      });

      test('should limit title to 5 words maximum', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is AI?';
        const aiResponse = 'AI is artificial intelligence.';
        const modelName = 'llama2';
        const longTitle =
            'This is a very long title with many words that should be truncated';

        mockOllamaService.responseToReturn = longTitle;

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        final words = result.split(' ');
        expect(words.length, lessThanOrEqualTo(5));
        expect(result, 'This is a very long');
      });

      test('should handle thinking content in title response', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is AI?';
        const aiResponse = 'AI is artificial intelligence.';
        const modelName = 'llama2';
        const titleWithThinking = '''<thinking>
I need to create a good title for this conversation about AI.
</thinking>

Artificial Intelligence Discussion''';

        mockOllamaService.responseToReturn = titleWithThinking;

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Artificial Intelligence Discussion');
        expect(result, isNot(contains('<thinking>')));
      });
    });

    group('Fallback Handling', () {
      test('should generate fallback title from user message keywords',
          () async {
        const chatId = 'test-chat-1';
        const userMessage =
            'Please explain machine learning algorithms and their applications';
        const aiResponse = 'Here is the explanation.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn =
            ''; // Empty response to trigger fallback

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, contains('machine'));
        expect(result, contains('learning'));
        expect(result, startsWith('Chat about'));
        // Note: 'algorithms' might be filtered out due to length/common word filtering
      });

      test('should use default fallback when no keywords found', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is this?';
        const aiResponse = 'This is that.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn =
            ''; // Empty response to trigger fallback

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Document Analysis Chat');
      });

      test('should handle invalid titles with less than 2 words', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is AI?';
        const aiResponse = 'AI is artificial intelligence.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn =
            'AI'; // Single word, should trigger fallback

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, isNot('AI'));
        expect(result, 'Document Analysis Chat'); // Should use fallback
      });
    });

    group('Edge Cases', () {
      test('should handle empty user message', () async {
        const chatId = 'test-chat-1';
        const userMessage = '';
        const aiResponse = 'I can help you with that.';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'General Chat';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'General Chat');
      });

      test('should handle empty AI response', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'Hello there';
        const aiResponse = '';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'Hello Chat';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Hello Chat');
      });

      test('should handle special characters in messages', () async {
        const chatId = 'test-chat-1';
        const userMessage = 'What is @#\$%^&*() this?';
        const aiResponse = 'This is a test with special characters!';
        const modelName = 'llama2';

        mockOllamaService.responseToReturn = 'Special Characters Test';

        final result = await titleGenerator.generateTitle(
          chatId: chatId,
          userMessage: userMessage,
          aiResponse: aiResponse,
          modelName: modelName,
        );

        expect(result, 'Special Characters Test');
      });
    });
  });
}
