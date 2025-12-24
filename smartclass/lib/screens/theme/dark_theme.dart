import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Color(0xFF3A7BFF),
  splashColor: Colors.blueAccent.shade100,
  scaffoldBackgroundColor: const Color(0xFF121212), //blue.shade50
  cardColor: const Color(0xFF1E1E1E),
  shadowColor: Color(0xFF474747),
  canvasColor: Color(0xFF000000),
  disabledColor:  const Color.fromARGB(255, 19, 19, 19),
  highlightColor: Colors.white,

  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF3A7BFF),
    foregroundColor: Colors.white,
  ),

  textTheme: const TextTheme(
    // labelMedium: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    bodySmall: TextStyle(color: Color(0xFF9E9E9E)), // grey[500]
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600,
    ),
  ),

  

  inputDecorationTheme: InputDecorationTheme(
    // labelStyle: const TextStyle(color: Colors.white),
    // prefixStyle: TextStyle(color: Colors.white),
    // suffixStyle: TextStyle(color: Colors.white),
    filled: true,

    fillColor: const Color(0xFF1E1E1E),
    floatingLabelStyle: const TextStyle(color: Color(0xFF3A7BFF)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFF3A7BFF), width: 2),
    ),
  ),

  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Color(0xFF3A7BFF), // Cursor color
    selectionColor: Color(
      0xFF3A7BFF,
    ).withAlpha((0.3 * 255).toInt()), // Drag selection color
    selectionHandleColor: Color(0xFF3A7BFF), // Handle color
  ),

  /* extensions: const <ThemeExtension<dynamic>>[
    CustomColors(
      success: Color(0xFF4CAF50),
      warning: Color(0xFFFFC107),
      error: Color.fromARGB(255, 255, 243, 82),
    ),
  ], */
  extensions: const [
    CustomColors(
      success: Color(0xFF4CAF50),
      warning: Color(0xFFFFC107),
      error: Color(0xFF9D2424),
    ),
  ],

  /* dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w500,
  ),) */
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
  CustomColors copyWith({Color? error, Color? success, Color? warning}) {
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
