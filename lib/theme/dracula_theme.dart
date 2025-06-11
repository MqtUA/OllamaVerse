import 'package:flutter/material.dart';

/// Dracula theme color palette
/// Based on the official Dracula theme: https://draculatheme.com/
class DraculaColors {
  // Primary colors - From official spec: https://spec.draculatheme.com/
  static const Color background = Color(0xFF1C1E26); // Much darker background (darker than official)
  static const Color currentLine = Color(0xFF44475A); // Current Line
  static const Color selection = Color(0xFF44475A); // Selection
  static const Color foreground = Color(0xFFF8F8F2); // Foreground
  
  // Accent colors - From official spec
  static const Color comment = Color(0xFF6272A4); // Comment
  static const Color cyan = Color(0xFF8BE9FD); // Cyan
  static const Color green = Color(0xFF50FA7B); // Green
  static const Color orange = Color(0xFFFFB86C); // Orange
  static const Color pink = Color(0xFFFF79C6); // Pink
  static const Color purple = Color(0xFFBD93F9); // Purple
  static const Color red = Color(0xFFFF5555); // Red
  static const Color yellow = Color(0xFFF1FA8C); // Yellow
  
  // Chat bubble colors - Darker to match Dracula spec
  static const Color userBubble = Color(0xFF44475A); // Selection color for user bubbles
  static const Color aiBubble = Color(0xFF282A36); // Background color for AI bubbles
  
  // Code block color - Distinct from chat bubbles
  static const Color codeBlock = Color(0xFF21222C); // Slightly lighter than background but darker than bubbles
}

/// Creates a Dracula-themed ThemeData for dark mode
ThemeData draculaDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DraculaColors.background,
    
    // Color scheme
    colorScheme: const ColorScheme.dark(
      primary: DraculaColors.purple,
      secondary: DraculaColors.pink,
      tertiary: DraculaColors.cyan,
      surface: DraculaColors.background,
      error: DraculaColors.red,
      onPrimary: DraculaColors.foreground,
      onSecondary: DraculaColors.foreground,
      onTertiary: DraculaColors.foreground,
      onSurface: DraculaColors.foreground,
      onError: DraculaColors.foreground,
      brightness: Brightness.dark,
    ),
    
    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: DraculaColors.background,
      foregroundColor: DraculaColors.foreground,
      elevation: 0,
    ),
    
    // Card theme
    cardColor: DraculaColors.currentLine,
    
    // Dialog theme
    dialogTheme: const DialogThemeData(
      backgroundColor: DraculaColors.background,
    ),
    
    // Floating action button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: DraculaColors.purple,
      foregroundColor: DraculaColors.foreground,
    ),
    
    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DraculaColors.currentLine,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DraculaColors.purple, width: 2),
      ),
    ),
    
    // Text theme
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: DraculaColors.foreground),
      bodyMedium: TextStyle(color: DraculaColors.foreground),
      bodySmall: TextStyle(color: DraculaColors.foreground),
      titleLarge: TextStyle(color: DraculaColors.foreground),
      titleMedium: TextStyle(color: DraculaColors.foreground),
      titleSmall: TextStyle(color: DraculaColors.foreground),
    ),
    
    // Icon theme
    iconTheme: const IconThemeData(
      color: DraculaColors.foreground,
    ),
    
    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DraculaColors.purple,
        foregroundColor: DraculaColors.foreground,
      ),
    ),
    
    // Divider color
    dividerColor: DraculaColors.comment,
    
    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return DraculaColors.purple;
          }
          return DraculaColors.comment;
        },
      ),
      checkColor: WidgetStateProperty.all(DraculaColors.foreground),
    ),
    
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return DraculaColors.green;
          }
          return DraculaColors.foreground.withAlpha(204); // 0.8 opacity
        },
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return DraculaColors.green.withAlpha(128); // 0.5 opacity
          }
          return DraculaColors.comment;
        },
      ),
    ),
  );
}
