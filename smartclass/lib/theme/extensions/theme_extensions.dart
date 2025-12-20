import 'package:flutter/material.dart';

/// Small ThemeExtension example for spacing tokens
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double small;
  final double medium;
  final double large;

  const AppSpacing({
    required this.small,
    required this.medium,
    required this.large,
  });

  @override
  AppSpacing copyWith({double? small, double? medium, double? large}) {
    return AppSpacing(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      small: lerpDouble(small, other.small, t) ?? small,
      medium: lerpDouble(medium, other.medium, t) ?? medium,
      large: lerpDouble(large, other.large, t) ?? large,
    );
  }
}

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a = a ?? 0;
  b = b ?? 0;
  return a + (b - a) * t;
}
