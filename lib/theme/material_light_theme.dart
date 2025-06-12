import 'package:flutter/material.dart';

/// Material Design 3 inspired light theme color palette
/// Based on modern design trends with clean, accessible colors
class MaterialLightColors {
  // Primary colors - Modern blue palette
  static const Color primary = Color(0xFF1976D2); // Material Blue 700
  static const Color primaryContainer = Color(0xFFE3F2FD); // Material Blue 50
  static const Color onPrimary = Color(0xFFFFFFFF); // White
  static const Color onPrimaryContainer =
      Color(0xFF0D47A1); // Material Blue 900

  // Secondary colors - Complementary teal
  static const Color secondary = Color(0xFF00796B); // Material Teal 700
  static const Color secondaryContainer = Color(0xFFE0F2F1); // Material Teal 50
  static const Color onSecondary = Color(0xFFFFFFFF); // White
  static const Color onSecondaryContainer =
      Color(0xFF004D40); // Material Teal 900

  // Tertiary colors - Accent purple
  static const Color tertiary = Color(0xFF7B1FA2); // Material Purple 700
  static const Color tertiaryContainer =
      Color(0xFFF3E5F5); // Material Purple 50
  static const Color onTertiary = Color(0xFFFFFFFF); // White
  static const Color onTertiaryContainer =
      Color(0xFF4A148C); // Material Purple 900

  // Surface colors - Clean whites and light grays
  static const Color surface = Color(0xFFFFFBFE); // Warm white
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Light gray
  static const Color onSurface = Color(0xFF1C1B1F); // Dark gray
  static const Color onSurfaceVariant = Color(0xFF49454F); // Medium gray

  // Background colors
  static const Color background = Color(0xFFFFFBFE); // Warm white
  static const Color onBackground = Color(0xFF1C1B1F); // Dark gray

  // Error colors
  static const Color error = Color(0xFFD32F2F); // Material Red 700
  static const Color errorContainer = Color(0xFFFFEBEE); // Material Red 50
  static const Color onError = Color(0xFFFFFFFF); // White
  static const Color onErrorContainer = Color(0xFFB71C1C); // Material Red 900

  // Outline colors
  static const Color outline = Color(0xFF79747E); // Medium gray
  static const Color outlineVariant = Color(0xFFCAC4D0); // Light gray

  // Chat bubble colors - Modern and clean
  static const Color userBubble = Color(0xFF1976D2); // Primary blue
  static const Color aiBubble = Color(0xFFFFFFFF); // Pure white
  static const Color userBubbleContainer = Color(0xFFE3F2FD); // Light blue
  static const Color aiBubbleContainer = Color(0xFFF8F9FA); // Very light gray

  // Code block colors
  static const Color codeBlock = Color(0xFFF5F5F5); // Light gray background
  static const Color codeBlockBorder = Color(0xFFE0E0E0); // Border gray

  // Shadow colors
  static const Color shadow = Color(0xFF000000); // Black
  static const Color scrim = Color(0xFF000000); // Black

  // Success color
  static const Color success = Color(0xFF388E3C); // Material Green 700
  static const Color successContainer = Color(0xFFE8F5E8); // Light green

  // Warning color
  static const Color warning = Color(0xFFF57C00); // Material Orange 700
  static const Color warningContainer = Color(0xFFFFF3E0); // Light orange
}

/// Creates a modern Material Design 3 inspired light theme
ThemeData materialLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: MaterialLightColors.background,
    fontFamily: 'Roboto',

    // Color scheme
    colorScheme: const ColorScheme.light(
      primary: MaterialLightColors.primary,
      onPrimary: MaterialLightColors.onPrimary,
      primaryContainer: MaterialLightColors.primaryContainer,
      onPrimaryContainer: MaterialLightColors.onPrimaryContainer,
      secondary: MaterialLightColors.secondary,
      onSecondary: MaterialLightColors.onSecondary,
      secondaryContainer: MaterialLightColors.secondaryContainer,
      onSecondaryContainer: MaterialLightColors.onSecondaryContainer,
      tertiary: MaterialLightColors.tertiary,
      onTertiary: MaterialLightColors.onTertiary,
      tertiaryContainer: MaterialLightColors.tertiaryContainer,
      onTertiaryContainer: MaterialLightColors.onTertiaryContainer,
      error: MaterialLightColors.error,
      onError: MaterialLightColors.onError,
      errorContainer: MaterialLightColors.errorContainer,
      onErrorContainer: MaterialLightColors.onErrorContainer,
      surface: MaterialLightColors.surface,
      onSurface: MaterialLightColors.onSurface,
      onSurfaceVariant: MaterialLightColors.onSurfaceVariant,
      outline: MaterialLightColors.outline,
      outlineVariant: MaterialLightColors.outlineVariant,
      shadow: MaterialLightColors.shadow,
      scrim: MaterialLightColors.scrim,
      brightness: Brightness.light,
    ),

    // AppBar theme - Clean and modern
    appBarTheme: const AppBarTheme(
      backgroundColor: MaterialLightColors.surface,
      foregroundColor: MaterialLightColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: MaterialLightColors.shadow,
      surfaceTintColor: MaterialLightColors.primary,
      titleTextStyle: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.27,
      ),
      iconTheme: IconThemeData(
        color: MaterialLightColors.onSurface,
        size: 24,
      ),
    ),

    // Card theme - Elevated and clean
    cardTheme: CardThemeData(
      color: MaterialLightColors.surface,
      shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    ),

    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor: MaterialLightColors.surface,
      surfaceTintColor: MaterialLightColors.primary,
      elevation: 6,
      shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.33,
      ),
      contentTextStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
    ),

    // Floating action button theme
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: MaterialLightColors.primary,
      foregroundColor: MaterialLightColors.onPrimary,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Input decoration theme - Modern and clean
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MaterialLightColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: MaterialLightColors.outline,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: MaterialLightColors.outline,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: MaterialLightColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: MaterialLightColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: MaterialLightColors.error,
          width: 2,
        ),
      ),
      labelStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
      hintStyle: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant.withValues(alpha: 0.6),
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

    // Text theme - Clean and readable
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.22,
      ),
      headlineLarge: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.33,
      ),
      titleLarge: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodyLarge: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.4,
        height: 1.33,
      ),
      labelLarge: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        height: 1.45,
      ),
    ),

    // Icon theme
    iconTheme: const IconThemeData(
      color: MaterialLightColors.onSurface,
      size: 24,
    ),

    // Button themes - Modern and accessible
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MaterialLightColors.primary,
        foregroundColor: MaterialLightColors.onPrimary,
        elevation: 2,
        shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.15),
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
        backgroundColor: MaterialLightColors.primary,
        foregroundColor: MaterialLightColors.onPrimary,
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
        foregroundColor: MaterialLightColors.primary,
        side: const BorderSide(
          color: MaterialLightColors.outline,
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
        foregroundColor: MaterialLightColors.primary,
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

    // Divider theme
    dividerTheme: DividerThemeData(
      color: MaterialLightColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return MaterialLightColors.primary;
        }
        return MaterialLightColors.surface;
      }),
      checkColor: WidgetStateProperty.all(MaterialLightColors.onPrimary),
      side: const BorderSide(
        color: MaterialLightColors.outline,
        width: 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return MaterialLightColors.primary;
        }
        return MaterialLightColors.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.selected)) {
          return MaterialLightColors.primary.withValues(alpha: 0.5);
        }
        return MaterialLightColors.surfaceVariant;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        return MaterialLightColors.outline;
      }),
    ),

    // Slider theme
    sliderTheme: SliderThemeData(
      activeTrackColor: MaterialLightColors.primary,
      inactiveTrackColor: MaterialLightColors.surfaceVariant,
      thumbColor: MaterialLightColors.primary,
      overlayColor: MaterialLightColors.primary.withValues(alpha: 0.12),
      valueIndicatorColor: MaterialLightColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.onPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.1,
        height: 1.43,
      ),
    ),

    // Drawer theme
    drawerTheme: DrawerThemeData(
      backgroundColor: MaterialLightColors.surface,
      surfaceTintColor: MaterialLightColors.primary,
      elevation: 1,
      shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
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
        color: MaterialLightColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Roboto',
        letterSpacing: 0.15,
        height: 1.5,
      ),
      subtitleTextStyle: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant,
        fontSize: 14,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
      leadingAndTrailingTextStyle: TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurfaceVariant,
        fontSize: 14,
        fontFamily: 'Roboto',
        letterSpacing: 0.25,
        height: 1.43,
      ),
    ),

    // Snackbar theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MaterialLightColors.onSurface,
      contentTextStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.surface,
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

    // Bottom sheet theme
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: MaterialLightColors.surface,
      surfaceTintColor: MaterialLightColors.primary,
      elevation: 8,
      shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.15),
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
        color: MaterialLightColors.onSurface,
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
        backgroundColor: WidgetStateProperty.all(MaterialLightColors.surface),
        surfaceTintColor: WidgetStateProperty.all(MaterialLightColors.primary),
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(
          MaterialLightColors.shadow.withValues(alpha: 0.15),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),

    // Popup menu theme
    popupMenuTheme: PopupMenuThemeData(
      color: MaterialLightColors.surface,
      surfaceTintColor: MaterialLightColors.primary,
      elevation: 8,
      shadowColor: MaterialLightColors.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.onSurface,
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
        color: MaterialLightColors.onSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        inherit: true,
        color: MaterialLightColors.surface,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
        letterSpacing: 0.4,
        height: 1.33,
      ),
    ),

    // Text selection theme - Visible selection colors
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: MaterialLightColors.primary,
      selectionColor: MaterialLightColors.primary.withValues(alpha: 0.3),
      selectionHandleColor: MaterialLightColors.primary,
    ),
  );
}
