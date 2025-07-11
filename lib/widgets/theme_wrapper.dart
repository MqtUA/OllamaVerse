import 'package:flutter/material.dart';

/// Simple theme wrapper that provides optimized theme switching
/// Replaces the over-engineered AnimatedThemeSwitcher with a clean solution
class ThemeWrapper extends StatelessWidget {
  final Widget child;

  const ThemeWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Simple RepaintBoundary for optimal performance
    // No unnecessary animation controllers or complex state management
    return RepaintBoundary(
      child: child,
    );
  }
}
