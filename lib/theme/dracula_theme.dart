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

    // Card theme - Elevated and clean (matching Material Light)
    cardTheme: CardThemeData(
      color: DraculaColors.currentLine,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    ),

    // Dialog theme (matching Material Light shapes)
    dialogTheme: DialogThemeData(
      backgroundColor: DraculaColors.background,
      surfaceTintColor: DraculaColors.purple,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.33,
      ),
      contentTextStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
    ),

    // Floating action button theme (matching Material Light shapes)
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: DraculaColors.purple,
      foregroundColor: DraculaColors.foreground,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Input decoration theme - Modern and clean (matching Material Light shapes)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DraculaColors.currentLine,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: DraculaColors.comment,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: DraculaColors.comment,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: DraculaColors.purple,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: DraculaColors.red,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: DraculaColors.red,
          width: 2,
        ),
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
      hintStyle: TextStyle(
        inherit: true,
        color: DraculaColors.comment.withValues(alpha: 0.6),
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
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

    // Button themes - Modern and accessible (matching Material Light shapes)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DraculaColors.purple,
        foregroundColor: DraculaColors.foreground,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
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

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DraculaColors.purple,
        side: const BorderSide(
          color: DraculaColors.purple,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
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

    // Divider theme (matching Material Light)
    dividerTheme: DividerThemeData(
      color: DraculaColors.comment,
      thickness: 1,
      space: 1,
    ),

    // List tile theme (matching Material Light shapes)
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

    // Checkbox theme (matching Material Light shapes)
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.purple;
        }
        return DraculaColors.background;
      }),
      checkColor: WidgetStateProperty.all(DraculaColors.foreground),
      side: const BorderSide(
        color: DraculaColors.comment,
        width: 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    // Switch theme (matching Material Light)
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.purple;
        }
        return DraculaColors.comment;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return DraculaColors.purple.withValues(alpha: 0.5);
        }
        return DraculaColors.currentLine;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        return DraculaColors.comment;
      }),
    ),

    // Slider theme (matching Material Light)
    sliderTheme: SliderThemeData(
      activeTrackColor: DraculaColors.purple,
      inactiveTrackColor: DraculaColors.currentLine,
      thumbColor: DraculaColors.purple,
      overlayColor: DraculaColors.purple.withValues(alpha: 0.12),
      valueIndicatorColor: DraculaColors.purple,
      valueIndicatorTextStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
    ),

    // Drawer theme (matching Material Light)
    drawerTheme: DrawerThemeData(
      backgroundColor: DraculaColors.background,
      surfaceTintColor: DraculaColors.purple,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
    ),

    // Snackbar theme (matching Material Light)
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DraculaColors.foreground,
      contentTextStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.background,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    ),

    // Bottom sheet theme (matching Material Light)
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: DraculaColors.background,
      surfaceTintColor: DraculaColors.purple,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
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

    // Menu theme (matching Material Light)
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(DraculaColors.background),
        surfaceTintColor: WidgetStateProperty.all(DraculaColors.purple),
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(
          Colors.black.withValues(alpha: 0.15),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),

    // Popup menu theme (matching Material Light)
    popupMenuTheme: PopupMenuThemeData(
      color: DraculaColors.background,
      surfaceTintColor: DraculaColors.purple,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
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

    // Tooltip theme (matching Material Light)
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: DraculaColors.foreground,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        inherit: true,
        color: DraculaColors.background,
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
      selectionColor: DraculaColors.purple.withValues(alpha: 0.3),
      selectionHandleColor: DraculaColors.purple,
    ),
  );
}
