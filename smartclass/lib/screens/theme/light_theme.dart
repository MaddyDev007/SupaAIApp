import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue,
  splashColor: Colors.blue.shade100,
  scaffoldBackgroundColor: Color(0xFFE3F2FD),  //blue.shade50
  cardColor: Colors.white,
  shadowColor: Color(0xFF000000),
  canvasColor: Colors.blue.shade100,
  disabledColor: Colors.white70,
  highlightColor: Colors.black,


  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    labelStyle: const TextStyle(color: Colors.black),
    // prefixStyle: TextStyle(color: Colors.black),
    // suffixStyle: TextStyle(color: Colors.black),
      fillColor: Colors.white,
      floatingLabelStyle: const TextStyle(color: Colors.blueAccent),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
  ),  

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),

  /* dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w500,
  ),), */

  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black),
    bodySmall: TextStyle(color: Color(0xFF616161)), //grey[700]
    titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600,
    ),
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Colors.blue, // Cursor color
    selectionColor: Colors.blue.withAlpha(
      (0.3 * 255).toInt(),
    ), // Drag selection color
    selectionHandleColor: Colors.blue, // Handle color
  ),

  

  extensions: const [
    CustomColors(
      success: Color(0xFF4CAF50),
      warning: Color(0xFFFFC107),
      error: Color(0xFFD32F2F),
    ),
  ],
);

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  final Color error;
  final Color success;
  final Color warning;

  const CustomColors({
    required this.error,
    required this.success,
    required this.warning,
  });

  @override
  CustomColors copyWith({
    Color? error,
    Color? success,
    Color? warning,
  }) {
    return CustomColors(
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
