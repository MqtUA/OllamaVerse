import 'package:flutter/material.dart';

/// Dracula theme color palette
/// Based on the official Dracula theme: https://draculatheme.com/
class DraculaColors {
  // Primary colors - From official spec: https://spec.draculatheme.com/
  static const Color background = Color(
    0xFF1C1E26,
  ); // Much darker background (darker than official)
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
  static const Color userBubble = Color(
    0xFF44475A,
  ); // Selection color for user bubbles
  static const Color aiBubble = Color(
    0xFF282A36,
  ); // Background color for AI bubbles

  // Code block color - Distinct from chat bubbles
  static const Color codeBlock = Color(
    0xFF21222C,
  ); // Slightly lighter than background but darker than bubbles
}

/// Creates a Dracula-themed ThemeData for dark mode
ThemeData draculaDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DraculaColors.background,
    fontFamily: 'Roboto',

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
      titleTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.27,
      ),
    ),

    // Card theme
    cardColor: DraculaColors.currentLine,

    // Dialog theme
    dialogTheme: const DialogThemeData(
      backgroundColor: DraculaColors.background,
      titleTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.33,
      ),
      contentTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
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
      labelStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
      hintStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.comment,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
    ),

    // Text theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.22,
      ),
      headlineLarge: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 32,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.33,
      ),
      titleLarge: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodyLarge: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.4,
        height: 1.33,
      ),
      labelLarge: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.45,
      ),
    ),

    // Icon theme
    iconTheme: const IconThemeData(color: DraculaColors.foreground),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DraculaColors.purple,
        foregroundColor: DraculaColors.foreground,
        textStyle: const TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.1,
          height: 1.4,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DraculaColors.purple,
        foregroundColor: DraculaColors.foreground,
        textStyle: const TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.1,
          height: 1.43,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DraculaColors.purple,
        side: const BorderSide(
          color: DraculaColors.purple,
          width: 1,
        ),
        textStyle: const TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.1,
          height: 1.43,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DraculaColors.purple,
        textStyle: const TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.1,
          height: 1.43,
        ),
      ),
    ),

    // List tile theme
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      titleTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.15,
        height: 1.5,
      ),
      subtitleTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.comment,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
      leadingAndTrailingTextStyle: TextStyle(
        inherit: true,
        color: DraculaColors.comment,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
    ),

    // Divider color
    dividerColor: DraculaColors.comment,

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.purple;
        }
        return DraculaColors.comment;
      }),
      checkColor: WidgetStateProperty.all(DraculaColors.foreground),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.green;
        }
        return DraculaColors.foreground.withAlpha(204); // 0.8 opacity
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.green.withAlpha(128); // 0.5 opacity
        }
        return DraculaColors.comment;
      }),
    ),

    // Dropdown menu theme
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
    ),

    // Menu theme
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(DraculaColors.background),
        elevation: WidgetStateProperty.all(8),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),

    // Popup menu theme
    popupMenuTheme: PopupMenuThemeData(
      color: DraculaColors.background,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
    ),

    // Tooltip theme
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: DraculaColors.currentLine,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.4,
        height: 1.33,
      ),
    ),

    // Text selection theme - Visible selection colors
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: DraculaColors.purple,
      selectionColor: DraculaColors.purple.withAlpha(77), // 0.3 opacity
      selectionHandleColor: DraculaColors.purple,
    ),
  );
}
