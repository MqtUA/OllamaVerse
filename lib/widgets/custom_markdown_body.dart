import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_highlighter/themes/github.dart';

/// A custom markdown body widget that properly handles code blocks in dark theme and LaTeX
class CustomMarkdownBody extends StatelessWidget {
  final String data;
  final double fontSize;
  final bool selectable;
  final void Function(String, String?, String)? onTapLink;

  const CustomMarkdownBody({
    super.key,
    required this.data,
    required this.fontSize,
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
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    
    // Extract code blocks from the markdown
    final codeBlocks = _extractCodeBlocks(data);
    
    // Create a column to hold all the content
    final List<Widget> contentWidgets = [];
    
    // Process the markdown content and code blocks
    String remainingText = data;
    int lastEnd = 0;
    
    // Sort code blocks by their position in the text
    codeBlocks.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    
    // Process each code block
    for (final codeBlock in codeBlocks) {
      // Add the text before this code block
      if (codeBlock.startIndex > lastEnd) {
        final textBefore = remainingText.substring(lastEnd, codeBlock.startIndex);
        if (textBefore.trim().isNotEmpty) {
          contentWidgets.add(_buildMarkdownSection(textBefore, textColor));
        }
      }
      
      // Add the code block with syntax highlighting
      contentWidgets.add(_buildCodeBlock(codeBlock.code, codeBlock.language, isDarkMode, fontSize));
      
      lastEnd = codeBlock.endIndex;
    }
    
    // Add any remaining text after the last code block
    if (lastEnd < remainingText.length) {
      final textAfter = remainingText.substring(lastEnd);
      if (textAfter.trim().isNotEmpty) {
        contentWidgets.add(_buildMarkdownSection(textAfter, textColor));
      }
    }
    
    // If no code blocks were found, just render the entire content as markdown
    if (contentWidgets.isEmpty) {
      contentWidgets.add(_buildMarkdownSection(data, textColor));
    }
    
    // Create the final widget
    Widget result = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentWidgets,
      ),
    );
    
    // Wrap with SelectionArea if content should be selectable
    if (selectable) {
      result = SelectionArea(child: result);
    }
    
    return result;
  }
  
  // Build a regular markdown section
  Widget _buildMarkdownSection(String markdown, Color? textColor) {
    return GptMarkdown(
      markdown,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
      ),
    );
  }
  
  // Build a code block with syntax highlighting
  Widget _buildCodeBlock(String code, String? language, bool isDarkMode, double fontSize) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null && language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0, right: 8.0),
              child: Text(
                language,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  fontSize: fontSize - 2,
                ),
              ),
            ),
          HighlightView(
            code,
            language: language ?? 'plaintext',
            theme: isDarkMode ? atomOneDarkTheme : githubTheme,
            padding: const EdgeInsets.all(8.0),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize - 1,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to represent a code block
class CodeBlock {
  final String code;
  final String? language;
  final int startIndex;
  final int endIndex;
  
  CodeBlock({
    required this.code,
    this.language,
    required this.startIndex,
    required this.endIndex,
  });
}

// Extract code blocks from markdown text
List<CodeBlock> _extractCodeBlocks(String markdown) {
  final List<CodeBlock> codeBlocks = [];
  final RegExp codeBlockRegex = RegExp(
    r'```([a-zA-Z0-9_+-]*)?\s*\n([\s\S]*?)\n```',
    multiLine: true,
  );
  
  // Find all code blocks
  final matches = codeBlockRegex.allMatches(markdown);
  
  for (final match in matches) {
    final language = match.group(1)?.trim();
    final code = match.group(2) ?? '';
    
    codeBlocks.add(CodeBlock(
      code: code,
      language: language,
      startIndex: match.start,
      endIndex: match.end,
    ));
  }
  
  return codeBlocks;
}
