import 'package:flutter/material.dart';

class AppTheme {
  // Colores principales
  static const Color primaryColor = Color(0xFFD4AF37); // Dorado
  static const Color secondaryColor = Color(0xFFE8B4B8); // Rosa Oro
  static const Color accentColor = Color(0xFF50C878); // Verde Esmeralda
  static const Color dangerColor = Color(0xFFFF6B6B); // Rojo Coral
  static const Color warningColor = Color(0xFFFFA500); // Naranja Ámbar
  static const Color infoColor = Color(0xFFA8C3D0); // Azul Plateado
  
  // Colores de fondo
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF2C2C2C);
  static const Color surfaceLight = Color(0xFFF8F4E6); // Blanco Marfil
  
  // Textos
  static const Color textPrimary = Color(0xFFF8F4E6);
  static const Color textSecondary = Color(0xFFD8D8D8); // Gris Perla
  static const Color textDisabled = Color(0xFF888888);
  
  // Bordes
  static const Color borderColor = Color(0xFF444444);
  
  // Gradientes
  static Gradient get primaryGradient => LinearGradient(
    colors: const [Color(0xFFD4AF37), Color(0xFFF8E08E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static Gradient get darkGradient => LinearGradient(
    colors: const [Color(0xFF121212), Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Text Styles usando fuentes del sistema
  static TextStyle get titleLarge => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: textPrimary,
    fontFamily: 'PlayfairDisplay',
  );
  
  static TextStyle get titleMedium => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    fontFamily: 'PlayfairDisplay',
  );
  
  static TextStyle get titleSmall => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'PlayfairDisplay',
  );
  
  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    fontFamily: 'Montserrat',
  );
  
  static TextStyle get bodyMedium => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    fontFamily: 'Montserrat',
  );
  
  static TextStyle get bodySmall => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textDisabled,
    fontFamily: 'Montserrat',
  );
  
  static TextStyle get button => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    fontFamily: 'Montserrat',
    letterSpacing: 1,
  );
  
  static TextStyle get caption => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    fontFamily: 'Montserrat',
    letterSpacing: 2,
  );
  
  // ThemeData para la app - VERSIÓN SIMPLIFICADA QUE SÍ FUNCIONA
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: false, // IMPORTANTE: false para evitar problemas
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundDark,
    
    // ColorScheme simplificado
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceDark,
    ),
    
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        fontFamily: 'PlayfairDisplay',
      ),
    ),
    
    // Textos
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        fontFamily: 'PlayfairDisplay',
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        fontFamily: 'PlayfairDisplay',
      ),
      displaySmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFamily: 'PlayfairDisplay',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        fontFamily: 'Montserrat',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        fontFamily: 'Montserrat',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textDisabled,
        fontFamily: 'Montserrat',
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black,
        fontFamily: 'Montserrat',
        letterSpacing: 1,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        fontFamily: 'Montserrat',
        letterSpacing: 2,
      ),
    ),
    
    // Botones
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        textStyle: button,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: borderColor),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Montserrat',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textDisabled,
        fontFamily: 'Montserrat',
      ),
    ),
    
    // Dividers
    dividerTheme: DividerThemeData(
      color: borderColor,
      thickness: 1,
      space: 20,
    ),
    
    // Progress Indicators
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryColor,
      circularTrackColor: surfaceDark,
    ),
    
    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceDark,
      contentTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textPrimary,
        fontFamily: 'Montserrat',
      ),
      actionTextColor: primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.black,
    ),
    
    // Bottom Navigation Bar
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: backgroundLight,
      selectedItemColor: primaryColor,
      unselectedItemColor: textDisabled,
    ),
  );
}