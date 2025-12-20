import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

ElevatedButtonThemeData appElevatedButtonTheme() {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.button,
      elevation: 0,
    ),
  );
}
