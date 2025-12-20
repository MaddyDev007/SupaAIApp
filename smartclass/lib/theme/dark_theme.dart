import 'package:flutter/material.dart';
import 'tokens/colors.dart';
import 'tokens/typography.dart';
import 'component_theme/button_theme.dart';
import 'extensions/theme_extensions.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,

  primaryColor: AppDarkColors.primary,
  scaffoldBackgroundColor: AppDarkColors.background,

  colorScheme: ColorScheme.dark(
    primary: AppDarkColors.primary,
    background: AppDarkColors.background,
    surface: AppDarkColors.surface,
    onPrimary: AppDarkColors.onPrimary,
    onSurface: AppDarkColors.textPrimary,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppDarkColors.background,
    foregroundColor: AppDarkColors.textPrimary,
    elevation: 0,
    centerTitle: true,
  ),

  elevatedButtonTheme: appElevatedButtonTheme(),

  textTheme: TextTheme(
    titleLarge: AppTextStyles.h2.copyWith(
      color: AppDarkColors.textPrimary,
    ),
    headlineSmall: AppTextStyles.h1.copyWith(
      color: AppDarkColors.textPrimary,
    ),
    bodyLarge: AppTextStyles.body.copyWith(
      color: AppDarkColors.textPrimary,
    ),
    bodyMedium: AppTextStyles.body.copyWith(
      color: AppDarkColors.textSecondary,
    ),
    labelLarge: AppTextStyles.button.copyWith(
      color: AppDarkColors.onPrimary,
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppDarkColors.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppDarkColors.primary.withOpacity(0.25),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppDarkColors.primary.withOpacity(0.5),
      ),
    ),
  ),

  cardTheme: CardThemeData(
    color: AppDarkColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 6,
  ),

  extensions: const <ThemeExtension<dynamic>>[
    AppSpacing(small: 8, medium: 16, large: 24),
  ],
);
