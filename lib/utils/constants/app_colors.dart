import 'package:flutter/material.dart';

class AppColors {
  // Colores principales
  static const Color primaryBackground = Color(0xFF0A0E21);
  static const Color secondaryBackground = Color(0xFF1D1F33);
  
  // Colores de acento (puedes ajustar estos colores)
  static const Color accentColor = Color(0xFFFF4081); // Rosa vibrante (Usado para Juez)
  static const Color primaryColor = Color(0xFF03DAC6); // Turquesa (Usado para Admin)
  
  // Colores de texto
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B0);
  static const Color hintText = Color(0xFF888888);
  
  // Colores de UI
  static const Color cardBackground = Color(0xFF2B2D42); // Nuevo color para tarjetas/inputs
  static const Color borderColor = Color(0xFF444444);
  static const Color borderFocus = Color(0xFF03DAC6); // Usado para input enfocado
  static const Color disabledColor = Color(0xFF555555);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336); // Nombre de constante corregido
  
  // Colores de Iconos
  static const Color iconSecondary = Color(0xFFB0B0B0); // Igual que secondaryText para hints/iconos
  
  // Gradientes predefinidos (Se mantienen, aunque no los usamos directamente en el Login/Welcome)
  static Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, primaryColor],
  );
  
  static Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBackground, secondaryBackground],
  );
}