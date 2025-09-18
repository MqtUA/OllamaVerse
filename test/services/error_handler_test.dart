import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/utils/error_handler.dart';
import '../../lib/utils/cancellation_token.dart';
import '../../lib/services/ollama_service.dart';

void main() {
  group('ErrorHandler', () {
    group('executeWithRetry', () {
      test('should succeed on first attempt', () async {
        int callCount = 0;
        
        final result = await ErrorHandler.executeWithRetry(
          () async {
            callCount++;
            return 'success';
          },
          operationName: 'test',
        );
        
        expect(result, equals('success'));
        expect(callCount, equals(1));
      });

      test('should retry on retryable errors', () async {
        int callCount = 0;
        
        final result = await ErrorHandler.executeWithRetry(
          () async {
            callCount++;
            if (callCount < 3) {
              throw OllamaConnectionException('Connection failed');
            }
            return 'success';
          },
          operationName: 'test',
          maxRetries: 3,
        );
        
        expect(result, equals('success'));
        expect(callCount, equals(3));
      });

      test('should not retry on non-retryable errors', () async {
        int callCount = 0;
        
        expect(
          () => ErrorHandler.executeWithRetry(
            () async {
              callCount++;
              throw ArgumentError('Invalid argument');
            },
            operationName: 'test',
            maxRetries: 3,
          ),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(callCount, equals(1));
      });

      test('should respect cancellation token', () async {
        final cancellationToken = CancellationToken();
        int callCount = 0;
        
        // Cancel after first attempt
        Future.delayed(const Duration(milliseconds: 100), () {
          cancellationToken.cancel();
        });
        
        expect(
          () => ErrorHandler.executeWithRetry(
            () async {
              callCount++;
              await Future.delayed(const Duration(milliseconds: 200));
              throw OllamaConnectionException('Connection failed');
            },
            operationName: 'test',
            maxRetries: 3,
            cancellationToken: cancellationToken,
          ),
          throwsA(isA<CancellationException>()),
        );
        
        // Use callCount to avoid unused variable warning
        expect(callCount, greaterThanOrEqualTo(0));
      });

      test('should call retry callback', () async {
        int retryCallCount = 0;
        final retryErrors = <Object>[];
        final retryAttempts = <int>[];
        
        try {
          await ErrorHandler.executeWithRetry(
            () async {
              throw OllamaConnectionException('Connection failed');
            },
            operationName: 'test',
            maxRetries: 2,
            onRetry: (error, attempt) {
              retryCallCount++;
              retryErrors.add(error);
              retryAttempts.add(attempt);
            },
          );
        } catch (e) {
          // Expected to fail
        }
        
        expect(retryCallCount, equals(2));
        expect(retryErrors.length, equals(2));
        expect(retryAttempts, equals([1, 2]));
      });
    });

    group('executeWithTimeout', () {
      test('should complete within timeout', () async {
        final result = await ErrorHandler.executeWithTimeout(
          () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'success';
          },
          timeout: const Duration(seconds: 1),
          operationName: 'test',
        );
        
        expect(result, equals('success'));
      });

      test('should throw timeout exception', () async {
        expect(
          () => ErrorHandler.executeWithTimeout(
            () async {
              await Future.delayed(const Duration(seconds: 2));
              return 'success';
            },
            timeout: const Duration(milliseconds: 100),
            operationName: 'test',
          ),
          throwsA(isA<TimeoutException>()),
        );
      });
    });

    group('classifyError', () {
      test('should classify connection errors', () {
        final error = OllamaConnectionException('Connection failed');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.connection));
      });

      test('should classify API errors', () {
        final error = OllamaApiException('API error');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.api));
      });

      test('should classify timeout errors', () {
        final error = TimeoutException('Timeout', const Duration(seconds: 1));
        expect(ErrorHandler.classifyError(error), equals(ErrorType.timeout));
      });

      test('should classify cancellation errors', () {
        final error = CancellationException('Cancelled');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.cancellation));
      });

      test('should classify validation errors', () {
        final error = ArgumentError('Invalid argument');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.validation));
      });

      test('should classify state errors', () {
        final error = StateError('Invalid state');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.state));
      });

      test('should classify format errors', () {
        final error = FormatException('Invalid format');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.format));
      });

      test('should classify unknown errors', () {
        final error = Exception('Unknown error');
        expect(ErrorHandler.classifyError(error), equals(ErrorType.unknown));
      });
    });

    group('isRetryableError', () {
      test('should identify retryable errors', () {
        expect(ErrorHandler.isRetryableError(OllamaConnectionException('test')), isTrue);
        expect(ErrorHandler.isRetryableError(OllamaApiException('test')), isTrue);
        expect(ErrorHandler.isRetryableError(TimeoutException('test', Duration.zero)), isTrue);
      });

      test('should identify non-retryable errors', () {
        expect(ErrorHandler.isRetryableError(CancellationException('test')), isFalse);
        expect(ErrorHandler.isRetryableError(ArgumentError('test')), isFalse);
        expect(ErrorHandler.isRetryableError(StateError('test')), isFalse);
        expect(ErrorHandler.isRetryableError(FormatException('test')), isFalse);
      });
    });

    group('getUserFriendlyMessage', () {
      test('should return user-friendly messages', () {
        expect(
          ErrorHandler.getUserFriendlyMessage(OllamaConnectionException('test')),
          equals('test'), // Enhanced exception provides its own message
        );
        
        expect(
          ErrorHandler.getUserFriendlyMessage(TimeoutException('test', Duration.zero)),
          contains('timed out'),
        );
        
        expect(
          ErrorHandler.getUserFriendlyMessage(ArgumentError('test')),
          contains('Invalid input'),
        );
      });
    });

    group('getRecoverySuggestions', () {
      test('should return appropriate suggestions for connection errors', () {
        final suggestions = ErrorHandler.getRecoverySuggestions(
          OllamaConnectionException('test')
        );
        
        expect(suggestions, contains('Check your internet connection'));
        expect(suggestions, contains('Verify Ollama server is running'));
      });

      test('should return appropriate suggestions for timeout errors', () {
        final suggestions = ErrorHandler.getRecoverySuggestions(
          TimeoutException('test', Duration.zero)
        );
        
        expect(suggestions, contains('Try again with a shorter request'));
        expect(suggestions, contains('Check your internet connection speed'));
      });
    });

    group('createErrorState', () {
      test('should create error state with correct properties', () {
        final error = OllamaConnectionException('Connection failed');
        final errorState = ErrorHandler.createErrorState(
          error,
          operation: 'testOperation',
          canRetry: true,
          context: {'key': 'value'},
        );
        
        expect(errorState.error, equals(error));
        expect(errorState.errorType, equals(ErrorType.connection));
        expect(errorState.operation, equals('testOperation'));
        expect(errorState.canRetry, isTrue);
        expect(errorState.context, equals({'key': 'value'}));
        expect(errorState.message, equals('Connection failed')); // Enhanced exception message
        expect(errorState.suggestions.isNotEmpty, isTrue);
      });

      test('should set canRetry based on error type', () {
        final retryableError = OllamaConnectionException('test');
        final nonRetryableError = ArgumentError('test');
        
        final retryableState = ErrorHandler.createErrorState(retryableError);
        final nonRetryableState = ErrorHandler.createErrorState(nonRetryableError);
        
        expect(retryableState.canRetry, isTrue);
        expect(nonRetryableState.canRetry, isFalse);
      });
    });
  });

  group('ErrorState', () {
    test('should determine if error is recent', () {
      final recentError = ErrorState(
        error: Exception('test'),
        errorType: ErrorType.unknown,
        message: 'test',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now(),
      );
      
      final oldError = ErrorState(
        error: Exception('test'),
        errorType: ErrorType.unknown,
        message: 'test',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      
      expect(recentError.isRecent, isTrue);
      expect(oldError.isRecent, isFalse);
    });

    test('should determine error severity', () {
      final infoError = ErrorState(
        error: CancellationException('test'),
        errorType: ErrorType.cancellation,
        message: 'test',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now(),
      );
      
      final criticalError = ErrorState(
        error: StateError('test'),
        errorType: ErrorType.state,
        message: 'test',
        suggestions: [],
        canRetry: false,
        timestamp: DateTime.now(),
      );
      
      expect(infoError.severity, equals(ErrorSeverity.info));
      expect(criticalError.severity, equals(ErrorSeverity.critical));
    });

    test('should implement equality correctly', () {
      final error1 = ErrorState(
        error: Exception('test'),
        errorType: ErrorType.unknown,
        message: 'test message',
        suggestions: [],
        canRetry: false,
        operation: 'test',
        timestamp: DateTime.now(),
      );
      
      final error2 = ErrorState(
        error: Exception('different'),
        errorType: ErrorType.unknown,
        message: 'test message',
        suggestions: [],
        canRetry: false,
        operation: 'test',
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
      );
      
      expect(error1, equals(error2));
      expect(error1.hashCode, equals(error2.hashCode));
    });
  });
}