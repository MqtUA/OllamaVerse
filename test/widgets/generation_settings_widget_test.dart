import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/generation_settings_indicator.dart';
import '../../lib/models/generation_settings.dart';
import '../../lib/models/chat.dart';

void main() {
  group('GenerationSettingsWidget Tests', () {
    // Since the GenerationSettingsWidget requires complex provider setup,
    // we'll focus on testing the simpler indicator widgets that don't require providers
    
    late GenerationSettings globalSettings;
    late Chat chatWithoutCustomSettings;
    late Chat chatWithCustomSettings;

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
        ),
      );
    });

    group('GenerationSettingsIndicator', () {
      Widget createIndicatorWidget({
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

      testWidgets('should not show indicator when chat has no custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(createIndicatorWidget(chat: chatWithoutCustomSettings));

        expect(find.byType(GenerationSettingsIndicator), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget); // Should render as SizedBox.shrink()
        expect(find.byIcon(Icons.tune), findsNothing);
      });

      testWidgets('should show indicator when chat has custom settings', (WidgetTester tester) async {
        await tester.pumpWidget(createIndicatorWidget(chat: chatWithCustomSettings));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
      });

      testWidgets('should show only icon in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createIndicatorWidget(
          chat: chatWithCustomSettings,
          compact: true,
        ));

        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.text('Custom'), findsNothing); // Should not show text in compact mode
      });

      testWidgets('should call onTap when tapped', (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(createIndicatorWidget(
          chat: chatWithCustomSettings,
          onTap: () => tapped = true,
        ));

        final inkWell = find.byType(InkWell);
        await tester.tap(inkWell);
        await tester.pumpAndSettle();

        expect(tapped, true);
      });

      testWidgets('should show tooltip with settings summary', (WidgetTester tester) async {
        await tester.pumpWidget(createIndicatorWidget(chat: chatWithCustomSettings));

        final tooltip = find.byType(Tooltip);
        expect(tooltip, findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('Custom Generation Settings'));
        expect(tooltipWidget.message, contains('Temperature: 0.80'));
        expect(tooltipWidget.message, contains('Top P: 0.95'));
      });
    });

    // Additional tests can be added here for other widget components
    // that don't require complex provider setup
  });
}