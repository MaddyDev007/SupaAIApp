import 'package:flutter/material.dart';
import 'tokens/colors.dart';
import 'tokens/typography.dart';
import 'component_theme/button_theme.dart';
import 'extensions/theme_extensions.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: false,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    background: AppColors.background,
    surface: AppColors.surface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: appElevatedButtonTheme(),
  textTheme: TextTheme(
    titleLarge: AppTextStyles.h2,
    headlineSmall: AppTextStyles.h1,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.body,
    labelLarge: AppTextStyles.button,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.24)),
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 6,
  ),
  extensions: const <ThemeExtension<dynamic>>[
    AppSpacing(small: 8, medium: 16, large: 24),
  ],
);
