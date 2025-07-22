import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/generation_settings_indicator.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';


void main() {
  group('GenerationSettingsIndicator', () {
    late GenerationSettings globalSettings;
    late Chat chatWithoutCustomSettings;
    late Chat chatWithCustomSettings;
    late Chat chatWithSameAsGlobalSettings;

    setUp(() {
      globalSettings = GenerationSettings.defaults();
      final testDateTime = DateTime.now();

      chatWithoutCustomSettings = Chat(
        id: 'chat-no-custom',
        title: 'Chat without custom settings',
        modelName: 'llama2',
        messages: [],
        createdAt: testDateTime,
        lastUpdatedAt: testDateTime,
      );

      chatWithCustomSettings = Chat(
        id: 'chat-with-custom',
        title: 'Chat with custom settings',
        modelName: 'llama2',
        messages: [],
        createdAt: testDateTime,
        lastUpdatedAt: testDateTime,
        customGenerationSettings: globalSettings.copyWith(
          temperature: 0.8,
          topP: 0.95,
          topK: 50,
        ),
      );

      chatWithSameAsGlobalSettings = Chat(
        id: 'chat-same-as-global',
        title: 'Chat with same as global settings',
        modelName: 'llama2',
        messages: [],
        createdAt: testDateTime,
        lastUpdatedAt: testDateTime,
        customGenerationSettings: globalSettings, // Same as global
      );
    });

    Widget createTestWidget({
      required Chat chat,
      VoidCallback? onTap,
      bool compact = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: GenerationSettingsIndicator(
            chat: chat,
            globalSettings: globalSettings,
            onTap: onTap,
            compact: compact,
          ),
        ),
      );
    }

    group('visibility', () {
      testWidgets('should not show indicator when chat has no custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithoutCustomSettings));

        expect(find.byType(GenerationSettingsIndicator), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
        expect(find.byIcon(Icons.tune), findsNothing);
      });

      testWidgets('should show indicator when chat has custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
      });

      testWidgets('should show indicator even when custom settings match global', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithSameAsGlobalSettings));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
      });
    });

    group('compact mode', () {
      testWidgets('should show only icon in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: true,
        ));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsNothing); // Should not show text in compact mode
      });

      testWidgets('should show icon and text in normal mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: false,
        ));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
      });

      testWidgets('should use smaller icon size in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: true,
        ));

        final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
        expect(icon.size, 14);
      });

      testWidgets('should use normal icon size in normal mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: false,
        ));

        final icon = tester.widget<Icon>(find.byIcon(Icons.tune));
        expect(icon.size, 16);
      });

      testWidgets('should use smaller padding in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: true,
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final padding = container.padding as EdgeInsets;
        expect(padding.top, 4);
        expect(padding.bottom, 4);
        expect(padding.left, 4);
        expect(padding.right, 4);
      });

      testWidgets('should use normal padding in normal mode', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          compact: false,
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final padding = container.padding as EdgeInsets;
        expect(padding.top, 6);
        expect(padding.bottom, 6);
        expect(padding.left, 6);
        expect(padding.right, 6);
      });
    });

    group('tooltip', () {
      testWidgets('should show tooltip with settings summary', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final tooltip = find.byType(Tooltip);
        expect(tooltip, findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('Custom Generation Settings'));
        expect(tooltipWidget.message, contains('Temperature: 0.80'));
        expect(tooltipWidget.message, contains('Top P: 0.95'));
        expect(tooltipWidget.message, contains('Top K: 50'));
      });

      testWidgets('should show tooltip when long pressed', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final indicator = find.byType(InkWell);
        await tester.longPress(indicator);
        await tester.pumpAndSettle();

        expect(find.textContaining('Custom Generation Settings'), findsOneWidget);
        expect(find.textContaining('Temperature: 0.80'), findsOneWidget);
      });

      testWidgets('should show appropriate message when settings match global', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithSameAsGlobalSettings));

        final tooltip = find.byType(Tooltip);
        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('Custom settings enabled (same as global)'));
      });

      testWidgets('should only show differences in tooltip', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final tooltip = find.byType(Tooltip);
        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        
        // Should show changed values
        expect(tooltipWidget.message, contains('Temperature: 0.80'));
        expect(tooltipWidget.message, contains('Top P: 0.95'));
        expect(tooltipWidget.message, contains('Top K: 50'));
        
        // Should not show unchanged values
        expect(tooltipWidget.message, isNot(contains('Repeat Penalty')));
        expect(tooltipWidget.message, isNot(contains('Max Tokens')));
        expect(tooltipWidget.message, isNot(contains('Threads')));
      });
    });

    group('user interaction', () {
      testWidgets('should call onTap when tapped', (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          onTap: () => tapped = true,
        ));

        final inkWell = find.byType(InkWell);
        await tester.tap(inkWell);
        await tester.pumpAndSettle();

        expect(tapped, true);
      });

      testWidgets('should not crash when onTap is null', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          chat: chatWithCustomSettings,
          onTap: null,
        ));

        final inkWell = find.byType(InkWell);
        await tester.tap(inkWell);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('should show ripple effect when tapped', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final inkWell = find.byType(InkWell);
        expect(inkWell, findsOneWidget);

        final inkWellWidget = tester.widget<InkWell>(inkWell);
        expect(inkWellWidget.borderRadius, BorderRadius.circular(12));
      });
    });

    group('styling', () {
      testWidgets('should use primary color theme', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        
        // Should use primary color with opacity
        expect(decoration.color, isNotNull);
        expect(decoration.border, isNotNull);
        expect(decoration.borderRadius, BorderRadius.circular(12));
      });

      testWidgets('should use consistent border radius', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(12));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, BorderRadius.circular(12));
      });

      testWidgets('should use appropriate text styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chat: chatWithCustomSettings));

        final text = tester.widget<Text>(find.text('Custom'));
        expect(text.style?.fontSize, 10);
        expect(text.style?.fontWeight, FontWeight.w600);
      });
    });

    group('GenerationSettingsBadge', () {
      testWidgets('should show badge with number of custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationSettingsBadge(
                chat: chatWithCustomSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        expect(find.byType(GenerationSettingsBadge), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // 3 different settings
      });

      testWidgets('should not show badge when no custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationSettingsBadge(
                chat: chatWithoutCustomSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
        expect(find.byIcon(Icons.tune), findsNothing);
      });
    });

    group('GenerationSettingsDot', () {
      testWidgets('should show simple dot indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationSettingsDot(
                chat: chatWithCustomSettings,
              ),
            ),
          ),
        );

        expect(find.byType(GenerationSettingsDot), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should call onTap when dot is tapped', (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationSettingsDot(
                chat: chatWithCustomSettings,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        final gestureDetector = find.byType(GestureDetector);
        await tester.tap(gestureDetector);
        await tester.pumpAndSettle();

        expect(tapped, true);
      });

      testWidgets('should not show dot when no custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenerationSettingsDot(
                chat: chatWithoutCustomSettings,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
      });
    });

    group('AnimatedGenerationSettingsIndicator', () {
      testWidgets('should show animated indicator', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedGenerationSettingsIndicator(
                chat: chatWithCustomSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        expect(find.byType(AnimatedGenerationSettingsIndicator), findsOneWidget);
        expect(find.byType(AnimatedBuilder), findsWidgets); // Multiple AnimatedBuilders are expected
      });

      testWidgets('should animate when settings are different', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedGenerationSettingsIndicator(
                chat: chatWithCustomSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        // Should start animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        
        expect(find.byType(AnimatedBuilder), findsWidgets); // Multiple AnimatedBuilders are expected
      });

      testWidgets('should not animate when settings are same as global', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedGenerationSettingsIndicator(
                chat: chatWithSameAsGlobalSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        expect(find.byType(AnimatedBuilder), findsWidgets); // Multiple AnimatedBuilders are expected
      });

      testWidgets('should not show when no custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedGenerationSettingsIndicator(
                chat: chatWithoutCustomSettings,
                globalSettings: globalSettings,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
      });
    });

    group('edge cases', () {
      testWidgets('should handle null custom settings gracefully', (WidgetTester tester) async {
        final chatWithNullSettings = Chat(
          id: 'chat-null',
          title: 'Chat with null settings',
          modelName: 'llama2',
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          customGenerationSettings: null,
        );

        await tester.pumpWidget(createTestWidget(chat: chatWithNullSettings));

        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle extreme settings values in tooltip', (WidgetTester tester) async {
        final chatWithExtremeSettings = Chat(
          id: 'chat-extreme',
          title: 'Chat with extreme settings',
          modelName: 'llama2',
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          customGenerationSettings: const GenerationSettings(
            temperature: 2.0,
            topP: 1.0,
            topK: 100,
            repeatPenalty: 2.0,
            maxTokens: 4096,
            numThread: 16,
          ),
        );

        await tester.pumpWidget(createTestWidget(chat: chatWithExtremeSettings));

        final tooltip = find.byType(Tooltip);
        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('Temperature: 2.00'));
        expect(tooltipWidget.message, contains('Top P: 1.00'));
        expect(tooltipWidget.message, contains('Top K: 100'));
      });

      testWidgets('should handle unlimited maxTokens in tooltip', (WidgetTester tester) async {
        final chatWithUnlimitedTokens = Chat(
          id: 'chat-unlimited',
          title: 'Chat with unlimited tokens',
          modelName: 'llama2',
          messages: [],
          createdAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
          customGenerationSettings: globalSettings.copyWith(maxTokens: -1),
        );

        await tester.pumpWidget(createTestWidget(chat: chatWithUnlimitedTokens));

        // Since maxTokens is same as global (-1), it shouldn't show in tooltip
        final tooltip = find.byType(Tooltip);
        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('Custom settings enabled (same as global)'));
      });
    });
  });
}