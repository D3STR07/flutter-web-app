import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../service/auth_service.dart';
import '../../../service/user_session.dart';
import '../../utils/constants/app_colors.dart';

class JudgeHomeScreen extends StatelessWidget {
  const JudgeHomeScreen({super.key});
  
  // Instancia del servicio - ya no es final
  AuthService get _authService => AuthService();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // SOLO EL HEADER CON NOMBRE Y NÚMERO DEL JUEZ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Avatar del juez
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentColor, width: 2),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.accentColor,
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Info del juez - NOMBRE Y NÚMERO
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NÚMERO Y NOMBRE DEL JUEZ
                        Text(
                          UserSession.displayName, // Esto ya tiene "Juez 12 - azahel"
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Estado
                        Text(
                          'Juez Conectado',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón logout
                  IconButton(
                    onPressed: () async {
                      await _authService.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Cerrar Sesión',
                  ),
                ],
              ),
            ),
            
            // CONTENIDO VACÍO POR AHORA
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: 100,
                      color: AppColors.accentColor.withOpacity(0.3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pantalla del Juez',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      UserSession.displayName,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Próximamente: Lista de participantes',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}