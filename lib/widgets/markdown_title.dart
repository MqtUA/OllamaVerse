import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A lightweight markdown renderer specifically for chat titles
///
/// This widget is optimized for short text with basic markdown formatting
/// such as bold, italic, and inline code, without the overhead of
/// handling complex elements like code blocks.
class MarkdownTitle extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const MarkdownTitle({
    super.key,
    required this.data,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback to simple text display if data is empty
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use GptMarkdown for rendering the title with markdown
    return GptMarkdown(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
