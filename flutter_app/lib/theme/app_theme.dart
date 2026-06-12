import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TransportHub — Style 1: Modern Material Design.
/// Trust blue + energetic orange palette.
class AppColors {
  static const blue = Color(0xFF1565D8);
  static const blue700 = Color(0xFF0F4FB0);
  static const blue50 = Color(0xFFE9F1FF);
  static const orange = Color(0xFFFF7A18);
  static const orange600 = Color(0xFFF06400);
  static const ink = Color(0xFF10243E);
  static const ink2 = Color(0xFF3A536E);
  static const muted = Color(0xFF6B7C93);
  static const line = Color(0xFFE4EBF3);
  static const bg = Color(0xFFF5F8FC);
  static const card = Colors.white;
  static const ok = Color(0xFF138A55);
  static const warn = Color(0xFFC9831A);
  static const danger = Color(0xFFD6453C);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: AppColors.blue,
        secondary: AppColors.orange,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.ink2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      chipTheme: const ChipThemeData(backgroundColor: AppColors.blue50),
    );
  }
}

/// Maps the string icon keys used in data into Flutter IconData.
class AppIcons {
  static const _map = <String, IconData>{
    'local_shipping': Icons.local_shipping,
    'inventory_2': Icons.inventory_2,
    'package_2': Icons.inventory_2_outlined,
    'local_post_office': Icons.local_post_office,
    'directions_bus': Icons.directions_bus,
    'local_taxi': Icons.local_taxi,
    'ac_unit': Icons.ac_unit,
    'precision_manufacturing': Icons.precision_manufacturing,
    'electric_bolt': Icons.electric_bolt,
    'send': Icons.send,
    'directions_boat': Icons.directions_boat,
    'bolt': Icons.bolt,
    'schedule': Icons.schedule,
    'home': Icons.home,
    'apartment': Icons.apartment,
    'flight': Icons.flight,
    'my_location': Icons.my_location,
    'medical_services': Icons.medical_services,
    'eco': Icons.eco,
    'pallet': Icons.pallet,
    'airport_shuttle': Icons.airport_shuttle,
    'sync': Icons.sync,
    'event_repeat': Icons.event_repeat,
    'badge': Icons.badge,
    'thermostat': Icons.thermostat,
    'route': Icons.route,
    'construction': Icons.construction,
    'monitoring': Icons.monitoring,
    'emergency': Icons.emergency,
    'anchor': Icons.anchor,
    'sailing': Icons.sailing,
  };
  static IconData of(String key) => _map[key] ?? Icons.local_shipping;
}

/// Gradient covers per category (mirrors the web app).
class CategoryArt {
  static List<Color> gradient(String cat) {
    switch (cat) {
      case 'movers':
        return [const Color(0xFFFF7A18), const Color(0xFFF06400)];
      case 'courier':
        return [const Color(0xFF138A55), const Color(0xFF0E6E44)];
      case 'coach':
        return [const Color(0xFF7C3AED), const Color(0xFF5B21B6)];
      case 'ride':
        return [const Color(0xFF0EA5E9), const Color(0xFF0369A1)];
      case 'coldchain':
        return [const Color(0xFF06B6D4), const Color(0xFF0E7490)];
      case 'ferry':
        return [const Color(0xFF2563EB), const Color(0xFF1E3A8A)];
      case 'heavy':
        return [const Color(0xFF475569), const Color(0xFF1E293B)];
      case 'ev':
        return [const Color(0xFF16A34A), const Color(0xFF15803D)];
      case 'air':
        return [const Color(0xFF0891B2), const Color(0xFF155E75)];
      default:
        return [AppColors.blue, AppColors.blue700];
    }
  }
}
