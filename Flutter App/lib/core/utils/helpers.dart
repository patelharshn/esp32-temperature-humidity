import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Helpers {
  Helpers._();

  /// Formats raw hex UID into neat uppercase blocks (e.g., "1A 2B 3C 4D")
  static String formatRfidUid(String rawUid) {
    final clean = rawUid.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
    if (clean.isEmpty) return rawUid.toUpperCase();

    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 2 == 0) {
        buffer.write(' ');
      }
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  /// Converts Celsius to Fahrenheit
  static double celsiusToFahrenheit(double c) {
    return (c * 9 / 5) + 32;
  }

  /// Calculates Heat Index (apparent temperature) in Celsius
  static double calculateHeatIndex(double tempC, double humidity) {
    if (tempC < 27.0 || humidity < 40.0) {
      return tempC; // Heat index formula is only valid for >= 27°C and >= 40% humidity
    }
    final t = celsiusToFahrenheit(tempC);
    final r = humidity;

    // Rothfusz regression equation
    double hi = -42.379 +
        2.04901523 * t +
        10.14333127 * r -
        0.22475541 * t * r -
        0.00683783 * t * t -
        0.05481717 * r * r +
        0.00122874 * t * t * r +
        0.00085282 * t * r * r -
        0.00000199 * t * t * r * r;

    // Convert back to Celsius
    return (hi - 32) * 5 / 9;
  }

  /// Categorizes ambient comfort level
  static String getComfortCategory(double tempC, double humidity) {
    if (tempC < 18) return 'Cool';
    if (tempC <= 24 && humidity >= 40 && humidity <= 60) return 'Comfortable';
    if (tempC > 24 && tempC <= 28) return 'Warm';
    if (tempC > 28) return 'Hot';
    return 'Moderate';
  }

  /// Shows a clean modern SnackBar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    Color bg = AppColors.darkCard;
    Color fg = Colors.white;

    if (isError) {
      bg = AppColors.error;
    } else if (isSuccess) {
      bg = AppColors.successDark;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: fg, fontWeight: FontWeight.w500),
        ),
        backgroundColor: bg,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
      ),
    );
  }
}
