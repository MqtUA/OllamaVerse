import 'package:flutter/material.dart';
import 'package:flutter_syntax_view/flutter_syntax_view.dart';

/// A custom syntax view widget that eliminates white borders
/// by completely wrapping the SyntaxView widget
class CustomSyntaxView extends StatelessWidget {
  final String code;
  final Syntax syntax;
  final double fontSize;
  final bool withLineNumbers;

  const CustomSyntaxView({
    super.key,
    required this.code,
    required this.syntax,
    this.fontSize = 14.0,
    this.withLineNumbers = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use a dark background color that matches the code block
    final backgroundColor = Colors.grey.shade900;
    
    return Container(
      color: backgroundColor,
      child: Theme(
        // Override the theme to ensure no white borders
        data: Theme.of(context).copyWith(
          dividerColor: backgroundColor,
          dividerTheme: const DividerThemeData(
            color: Colors.transparent,
            space: 0,
            thickness: 0,
          ),
        ),
        child: ClipRect(
          child: Stack(
            children: [
              // Background layer to cover any gaps
              Positioned.fill(
                child: Container(
                  color: backgroundColor,
                ),
              ),
              
              // The actual syntax view with modified styling
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: SyntaxView(
                  code: code,
                  syntax: syntax,
                  syntaxTheme: SyntaxTheme.dracula(),
                  fontSize: fontSize,
                  withZoom: false,
                  withLinesCount: withLineNumbers,
                ),
              ),
              
              // Top border cover
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: Container(
                  color: backgroundColor,
                ),
              ),
              
              // Bottom border cover
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 2,
                child: Container(
                  color: backgroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
