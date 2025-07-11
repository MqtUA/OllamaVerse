import 'package:flutter/material.dart';
import '../theme/dracula_theme.dart';
import '../theme/material_light_theme.dart';

/// Centralized theme utility for thinking widgets
/// Eliminates duplicate color logic across thinking widgets
class ThinkingTheme {
  static ThinkingColors getColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkColors : _lightColors;
  }

  static final _darkColors = ThinkingColors(
    bubbleBackground: DraculaColors.background.withAlpha(128),
    border: DraculaColors.purple.withAlpha(102),
    icon: DraculaColors.purple,
    text: DraculaColors.purple,
    summary: DraculaColors.comment,
    divider: DraculaColors.selection,
    liveBubbleBackground: DraculaColors.purple.withAlpha(51),
    liveBorder: DraculaColors.purple.withAlpha(128),
  );

  static final _lightColors = ThinkingColors(
    bubbleBackground: MaterialLightColors.surfaceVariant.withAlpha(179),
    border: MaterialLightColors.primary.withAlpha(77),
    icon: MaterialLightColors.primary,
    text: MaterialLightColors.primary,
    summary: MaterialLightColors.onSurfaceVariant,
    divider: MaterialLightColors.outline.withAlpha(128),
    liveBubbleBackground: Colors.purple.shade50,
    liveBorder: Colors.purple.shade200,
  );
}

/// Color scheme for thinking widgets
class ThinkingColors {
  final Color bubbleBackground;
  final Color border;
  final Color icon;
  final Color text;
  final Color summary;
  final Color divider;
  final Color liveBubbleBackground;
  final Color liveBorder;

  const ThinkingColors({
    required this.bubbleBackground,
    required this.border,
    required this.icon,
    required this.text,
    required this.summary,
    required this.divider,
    required this.liveBubbleBackground,
    required this.liveBorder,
  });
}

/// Common styling constants for thinking widgets
class ThinkingConstants {
  static const double borderRadius = 12.0;
  static const EdgeInsets margin = EdgeInsets.only(bottom: 8.0);
  static const EdgeInsets padding = EdgeInsets.all(12.0);
  static const EdgeInsets contentPadding =
      EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0);
  static const double borderWidth = 1.0;
  static const double iconSize = 16.0;
  static const double expandIconSize = 20.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  static const List<BoxShadow> boxShadow = [
    BoxShadow(
      color: Color.fromARGB(26, 0, 0, 0), // 0.1 alpha
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}
