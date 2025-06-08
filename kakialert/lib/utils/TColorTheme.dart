import 'package:flutter/material.dart';

class TColorTheme {
  // Primary Colors
  static const Color primaryOrange = Color(0xFFFF8852);
  static const Color primaryRed = Color(0xFFFF7E7B);
  static const Color primaryBlue = Color(0xFF004CFD);

  // Secondary Colors
  static const Color darkBlue = Color(0xFF313A51);
  static const Color gray = Color(0xFF8B8B8B);
  static const Color lightGray = Color(0xFFF5F5FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Incident Colors
  static const Color medical = Color(0xFFDBE790);
  static const Color fire = Color(0xFFF5A6A6);
  static const Color accident = Color(0xFFD4CEFA);
  static const Color violence = Color(0xFFF5A6DF);
  static const Color hdb = Color(0xFFA6D4F5);
  static const Color others = Color(0xFFCBCBCB);
  static const Color rescue = Color(0xFFF5E8A6);
  static const Color mrt = Color(0xFFA7E5D4);

  static Color getIncidentColor(String incidentType) {
    switch (incidentType.toLowerCase()) {
      case 'medical':
        return TColorTheme.medical;
      case 'fire':
        return TColorTheme.fire;
      case 'accident':
        return TColorTheme.accident;
      case 'violence':
        return TColorTheme.violence;
      case 'hdb':
      case 'hdb_facilities':
        return TColorTheme.hdb;
      case 'rescue':
        return TColorTheme.rescue;
      case 'mrt':
        return TColorTheme.mrt;
      default:
        return TColorTheme.others;
    }
  }
}
