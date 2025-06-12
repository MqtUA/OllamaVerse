import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../theme/dracula_theme.dart';
import '../theme/material_light_theme.dart';

/// A custom markdown body widget that properly handles code blocks in dark theme and LaTeX
class CustomMarkdownBody extends StatelessWidget {
  final String data;
  final double fontSize;
  final bool selectable;
  final Function(String, String?, String?)? onTapLink;

  const CustomMarkdownBody({
    super.key,
    required this.data,
    this.fontSize = 14.0,
    this.selectable = true,
    this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback to simple text display if data is empty
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    // Configure colors based on theme
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width <= 600;

    // Create the markdown widget with our configuration
    Widget markdownWidget = GptMarkdown(
      data,
      style: TextStyle(
          fontSize: fontSize,
          color: Theme.of(context).textTheme.bodyMedium?.color),
    );

    // Wrap with SelectionArea if content should be selectable
    if (selectable) {
      markdownWidget = SelectionArea(child: markdownWidget);
    }

    // For mobile screens, we need to ensure code blocks aren't oversized
    if (isSmallScreen) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Builder(
          builder: (context) {
            // Apply custom styling to code blocks
            return Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.copyWith(
                      bodyMedium:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                backgroundColor: Colors.transparent,
                              ),
                    ),
                // Use appropriate code block color based on theme
                canvasColor: isDarkMode
                    ? DraculaColors.codeBlock
                    : MaterialLightColors.codeBlock,
              ),
              child: markdownWidget,
            );
          },
        ),
      );
    }

    // For larger screens, we keep the horizontal scrolling behavior
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Builder(
          builder: (context) {
            // Apply custom styling to code blocks
            return Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.copyWith(
                      bodyMedium:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                backgroundColor: Colors.transparent,
                              ),
                    ),
                // Use appropriate code block color based on theme
                canvasColor: isDarkMode
                    ? DraculaColors.codeBlock
                    : MaterialLightColors.codeBlock,
              ),
              child: markdownWidget,
            );
          },
        ),
      ),
    );
  }
}
