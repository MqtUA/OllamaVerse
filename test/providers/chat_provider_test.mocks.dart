// Mocks generated by Mockito 5.4.6 from annotations
// in ollamaverse/test/providers/chat_provider_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:ui' as _i12;

import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i8;
import 'package:ollamaverse/models/app_settings.dart' as _i3;
import 'package:ollamaverse/models/chat.dart' as _i10;
import 'package:ollamaverse/models/message.dart' as _i7;
import 'package:ollamaverse/models/ollama_response.dart' as _i2;
import 'package:ollamaverse/models/processed_file.dart' as _i6;
import 'package:ollamaverse/providers/settings_provider.dart' as _i11;
import 'package:ollamaverse/services/chat_history_service.dart' as _i9;
import 'package:ollamaverse/services/ollama_service.dart' as _i4;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeOllamaResponse_0 extends _i1.SmartFake
    implements _i2.OllamaResponse {
  _FakeOllamaResponse_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAppSettings_1 extends _i1.SmartFake implements _i3.AppSettings {
  _FakeAppSettings_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeOllamaService_2 extends _i1.SmartFake implements _i4.OllamaService {
  _FakeOllamaService_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [OllamaService].
///
/// See the documentation for Mockito's code generation for more information.
class MockOllamaServiceTest extends _i1.Mock implements _i4.OllamaService {
  MockOllamaServiceTest() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.Future<List<String>> getModels() => (super.noSuchMethod(
        Invocation.method(
          #getModels,
          [],
        ),
        returnValue: _i5.Future<List<String>>.value(<String>[]),
      ) as _i5.Future<List<String>>);

  @override
  _i5.Future<bool> testConnection() => (super.noSuchMethod(
        Invocation.method(
          #testConnection,
          [],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<void> refreshModels() => (super.noSuchMethod(
        Invocation.method(
          #refreshModels,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<_i2.OllamaResponse> generateResponseWithContext(
    String? prompt, {
    String? model,
    List<_i6.ProcessedFile>? processedFiles,
    List<int>? context,
    List<_i7.Message>? conversationHistory,
    int? contextLength,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateResponseWithContext,
          [prompt],
          {
            #model: model,
            #processedFiles: processedFiles,
            #context: context,
            #conversationHistory: conversationHistory,
            #contextLength: contextLength,
          },
        ),
        returnValue: _i5.Future<_i2.OllamaResponse>.value(_FakeOllamaResponse_0(
          this,
          Invocation.method(
            #generateResponseWithContext,
            [prompt],
            {
              #model: model,
              #processedFiles: processedFiles,
              #context: context,
              #conversationHistory: conversationHistory,
              #contextLength: contextLength,
            },
          ),
        )),
      ) as _i5.Future<_i2.OllamaResponse>);

  @override
  _i5.Future<String> generateResponseWithFiles(
    String? prompt, {
    String? model,
    List<_i6.ProcessedFile>? processedFiles,
    List<int>? context,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateResponseWithFiles,
          [prompt],
          {
            #model: model,
            #processedFiles: processedFiles,
            #context: context,
          },
        ),
        returnValue: _i5.Future<String>.value(_i8.dummyValue<String>(
          this,
          Invocation.method(
            #generateResponseWithFiles,
            [prompt],
            {
              #model: model,
              #processedFiles: processedFiles,
              #context: context,
            },
          ),
        )),
      ) as _i5.Future<String>);

  @override
  _i5.Stream<_i2.OllamaStreamResponse> generateStreamingResponseWithContext(
    String? prompt, {
    String? model,
    List<_i6.ProcessedFile>? processedFiles,
    List<int>? context,
    List<_i7.Message>? conversationHistory,
    int? contextLength,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateStreamingResponseWithContext,
          [prompt],
          {
            #model: model,
            #processedFiles: processedFiles,
            #context: context,
            #conversationHistory: conversationHistory,
            #contextLength: contextLength,
          },
        ),
        returnValue: _i5.Stream<_i2.OllamaStreamResponse>.empty(),
      ) as _i5.Stream<_i2.OllamaStreamResponse>);

  @override
  _i5.Stream<String> generateStreamingResponseWithFiles(
    String? prompt, {
    String? model,
    List<_i6.ProcessedFile>? processedFiles,
    List<int>? context,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateStreamingResponseWithFiles,
          [prompt],
          {
            #model: model,
            #processedFiles: processedFiles,
            #context: context,
          },
        ),
        returnValue: _i5.Stream<String>.empty(),
      ) as _i5.Stream<String>);

  @override
  _i5.Future<String> generateResponse(
    String? prompt, {
    String? model,
    List<int>? context,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateResponse,
          [prompt],
          {
            #model: model,
            #context: context,
          },
        ),
        returnValue: _i5.Future<String>.value(_i8.dummyValue<String>(
          this,
          Invocation.method(
            #generateResponse,
            [prompt],
            {
              #model: model,
              #context: context,
            },
          ),
        )),
      ) as _i5.Future<String>);

  @override
  _i5.Stream<String> generateStreamingResponse(
    String? prompt, {
    String? model,
    List<int>? context,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #generateStreamingResponse,
          [prompt],
          {
            #model: model,
            #context: context,
          },
        ),
        returnValue: _i5.Stream<String>.empty(),
      ) as _i5.Stream<String>);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [ChatHistoryService].
///
/// See the documentation for Mockito's code generation for more information.
class MockChatHistoryServiceTest extends _i1.Mock
    implements _i9.ChatHistoryService {
  MockChatHistoryServiceTest() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i5.Stream<List<_i10.Chat>> get chatStream => (super.noSuchMethod(
        Invocation.getter(#chatStream),
        returnValue: _i5.Stream<List<_i10.Chat>>.empty(),
      ) as _i5.Stream<List<_i10.Chat>>);

  @override
  List<_i10.Chat> get chats => (super.noSuchMethod(
        Invocation.getter(#chats),
        returnValue: <_i10.Chat>[],
      ) as List<_i10.Chat>);

  @override
  bool get isInitialized => (super.noSuchMethod(
        Invocation.getter(#isInitialized),
        returnValue: false,
      ) as bool);

  @override
  _i5.Future<void> saveChat(_i10.Chat? chat) => (super.noSuchMethod(
        Invocation.method(
          #saveChat,
          [chat],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<_i10.Chat?> loadChat(String? chatId) => (super.noSuchMethod(
        Invocation.method(
          #loadChat,
          [chatId],
        ),
        returnValue: _i5.Future<_i10.Chat?>.value(),
      ) as _i5.Future<_i10.Chat?>);

  @override
  _i5.Future<void> deleteChat(String? chatId) => (super.noSuchMethod(
        Invocation.method(
          #deleteChat,
          [chatId],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> dispose() => (super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);
}

/// A class which mocks [SettingsProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockSettingsProviderTest extends _i1.Mock
    implements _i11.SettingsProvider {
  MockSettingsProviderTest() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.AppSettings get settings => (super.noSuchMethod(
        Invocation.getter(#settings),
        returnValue: _FakeAppSettings_1(
          this,
          Invocation.getter(#settings),
        ),
      ) as _i3.AppSettings);

  @override
  bool get isLoading => (super.noSuchMethod(
        Invocation.getter(#isLoading),
        returnValue: false,
      ) as bool);

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i5.Future<void> updateSettings({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? showLiveResponse,
    int? contextLength,
    String? systemPrompt,
    bool? thinkingBubbleDefaultExpanded,
    bool? thinkingBubbleAutoCollapse,
    bool? darkMode,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #updateSettings,
          [],
          {
            #ollamaHost: ollamaHost,
            #ollamaPort: ollamaPort,
            #authToken: authToken,
            #fontSize: fontSize,
            #showLiveResponse: showLiveResponse,
            #contextLength: contextLength,
            #systemPrompt: systemPrompt,
            #thinkingBubbleDefaultExpanded: thinkingBubbleDefaultExpanded,
            #thinkingBubbleAutoCollapse: thinkingBubbleAutoCollapse,
            #darkMode: darkMode,
          },
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i4.OllamaService getOllamaService() => (super.noSuchMethod(
        Invocation.method(
          #getOllamaService,
          [],
        ),
        returnValue: _FakeOllamaService_2(
          this,
          Invocation.method(
            #getOllamaService,
            [],
          ),
        ),
      ) as _i4.OllamaService);

  @override
  _i5.Future<String> getLastSelectedModel() => (super.noSuchMethod(
        Invocation.method(
          #getLastSelectedModel,
          [],
        ),
        returnValue: _i5.Future<String>.value(_i8.dummyValue<String>(
          this,
          Invocation.method(
            #getLastSelectedModel,
            [],
          ),
        )),
      ) as _i5.Future<String>);

  @override
  _i5.Future<void> setLastSelectedModel(String? modelName) =>
      (super.noSuchMethod(
        Invocation.method(
          #setLastSelectedModel,
          [modelName],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  void addListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i12.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}
