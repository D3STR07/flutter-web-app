import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/constants/app_colors.dart';
import '../../utils/constants/app_strings.dart'; // Importación de constantes

// Convertimos a StatefulWidget para gestionar el ciclo de vida de la orientación
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  // Constantes de Alfa (Opacidad * 255) para evitar el método .withOpacity() obsoleto
  static const int alpha90Percent = 230; // ~0.9
  static const int alpha70Percent = 179; // ~0.7
  static const int alpha60Percent = 153; // ~0.6
  static const int alpha50Percent = 128; // ~0.5
  static const int alpha40Percent = 102; // ~0.4
  static const int alpha30Percent = 77;  // ~0.3
  static const int alpha20Percent = 51;  // ~0.2
  
  // Lógica para la animación
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. **Manejo de Orientación:** Establecer la orientación una sola vez.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // 2. **Animación Inicial:**
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Duración de la animación
    );

    // Animación de opacidad (fade in) para todo el contenido
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut), 
      ),
    );

    // Animación de deslizamiento (slide up) para el botón
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), 
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut), 
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Restaurar orientación al salir (opcional, pero buena práctica)
    SystemChrome.setPreferredOrientations(DeviceOrientation.values); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: Stack(
        children: [
          // Fondo decorativo
          _buildBackground(),

          // Contenido principal animado
          FadeTransition( 
            opacity: _opacityAnimation,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Icono principal
                      _buildLogo(),

                      const SizedBox(height: 50),

                      // Título principal
                      _buildTitle(),

                      const SizedBox(height: 12),

                      // Subtítulo
                      _buildSubtitle(),

                      const SizedBox(height: 80),

                      // Botón de acción con animación de deslizamiento
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildStartButton(context),
                      ),

                      const SizedBox(height: 30),

                      // Texto informativo (Versión, Año)
                      _buildInfoText(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Footer con información del evento
          _buildEventFooter(),
        ],
      ),
    );
  }

  // --- Widgets Refactorizados y Corregidos ---

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryBackground, 
            AppColors.primaryBackground, 
          ],
        ),
      ),
      child: Opacity(
        opacity: 0.1, 
        child: Image.asset(
          'assets/images/pattern_bg.png', 
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        // Corregido: Usamos .withAlpha(alpha50Percent) en lugar de .withOpacity(0.5)
        color: AppColors.primaryBackground.withAlpha(alpha50Percent), 
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            // Corregido: Usamos .withAlpha(alpha30Percent) en lugar de .withOpacity(0.3)
            color: AppColors.accentColor.withAlpha(alpha30Percent),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask( 
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AppColors.accentColor],
            ).createShader(bounds);
          },
          child: const Icon(
            Icons.local_florist_rounded, 
            size: 70,
            color: Colors.white, 
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Señorita',
          style: GoogleFonts.playfairDisplay(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            // CORRECCIÓN CLAVE: Usamos .withAlpha(alpha90Percent)
            color: AppColors.primaryText.withAlpha(alpha90Percent),
            letterSpacing: 2.0,
            shadows: const [
              Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2)
            ]
          ),
        ),
        Text(
          'NOCHE BUENA', 
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 55, 
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = LinearGradient(
                // CORRECCIÓN CLAVE: Usamos withAlpha(255) y withAlpha(alpha70Percent)
                colors: [AppColors.accentColor.withAlpha(255), AppColors.accentColor.withAlpha(alpha70Percent), Colors.white],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(
                const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0), 
              ),
            letterSpacing: 3.0,
            height: 0.8, 
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Text(
      AppStrings.welcomeSubtitle, // Asumiendo que esta constante existe
      textAlign: TextAlign.center,
      style: GoogleFonts.montserrat(
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: AppColors.secondaryText,
        letterSpacing: 1.0,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: 250, 
      height: 60, 
      child: ElevatedButton(
        onPressed: () {
          // Navegar a la pantalla de login (reemplazar la ruta actual)
          Navigator.pushReplacementNamed(context, AppStrings.routeLogin);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentColor,
          foregroundColor: Colors.white,
          elevation: 12, 
          // Corregido: Usamos .withAlpha(alpha60Percent)
          shadowColor: AppColors.accentColor.withAlpha(alpha60Percent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), 
          ),
        ),
        child: Text(
          'INICIAR',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoText() {
    return Column(
      children: [
        Text(
          'Certamen ${DateTime.now().year}',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildEventFooter() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            height: 1,
            width: 100,
            // Corregido: Usamos .withAlpha(alpha40Percent)
            color: AppColors.borderColor.withAlpha(alpha40Percent),
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.eventHost, // Asumiendo que esta constante existe
            style: GoogleFonts.montserrat(
              fontSize: 12,
              // Corregido: Usamos .withAlpha(alpha70Percent)
              color: AppColors.hintText.withAlpha(alpha70Percent),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Versión ${AppStrings.appVersion}', // Asumiendo que esta constante existe
            style: GoogleFonts.montserrat(
              fontSize: 10,
              // Corregido: Usamos .withAlpha(alpha50Percent)
              color: AppColors.hintText.withAlpha(alpha50Percent),
            ),
          ),
        ],
      ),
    );
  }
}