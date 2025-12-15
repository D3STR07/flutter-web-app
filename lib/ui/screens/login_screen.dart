import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../service/auth_service.dart';
import '../../../service/user_session.dart';
import '../../utils/constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _selectedRole = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // SOLUCIÓN: Permitir cargar fuentes en runtime o remover esta línea
    GoogleFonts.config.allowRuntimeFetching = true; // CAMBIADO DE false A true
    UserSession.clear();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final code = _codeController.text.trim();
      
      print('🔐 INTENTANDO LOGIN');
      print('------------------------------------------');
      print('📝 Código ingresado: $code');
      print('🎯 Rol seleccionado: $_selectedRole');
      print('------------------------------------------');
      
      Map<String, dynamic> result;
      
      // Determinar qué tipo de login realizar según el rol
      if (_selectedRole == 'admin') {
        result = await _authService.loginAdmin(code);
      } else {
        result = await _authService.loginWithCode(code);
      }
      
      print('📨 Resultado del servicio:');
      print('   Success: ${result['success']}');
      print('   Message: ${result['message']}');
      
      if (result['success'] == true) {
        if (_selectedRole == 'admin') {
          // Login de admin exitoso
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Administrador conectado'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );

          print('==========================================');
          print('🔑 LOGIN ADMIN EXITOSO');
          print('==========================================');
          print('👤 Administrador: ${result['user']?['name'] ?? 'Admin'}');
          print('⏰ Login time: ${DateTime.now()}');
          print('==========================================');

          await Future.delayed(const Duration(milliseconds: 800));
          print('📍 Navegando a panel admin...');
          Navigator.pushReplacementNamed(context, '/admin-home');
        } else {
          // Login de juez exitoso
          final user = result['user'] as Map<String, dynamic>;
          final role = user['role'];
          final userName = user['name'] ?? '';
          final judgeNumber = user['judgeNumber'] ?? '';
          
          final displayName = judgeNumber.isNotEmpty 
              ? '$judgeNumber - $userName'
              : userName;
              
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $displayName conectado'),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );

          print('==========================================');
          print('🔑 LOGIN JUEZ EXITOSO');
          print('==========================================');
          print('👤 Usuario: $displayName');
          print('🏷️ ID Interno: ${user['idInterno']}');
          print('🎯 Rol: $role');
          print('🆔 Firebase ID: ${user['firebaseId']}');
          print('⏰ Login time: ${DateTime.now()}');
          print('==========================================');

          await Future.delayed(const Duration(milliseconds: 800));

          // Inicializar contexto del juez
          await UserSession.initJuezContext();
          
          // LIMPIAR SIEMPRE la selección anterior
          UserSession.clearSelectedParticipante();
          
          // SIEMPRE ir a seleccionar participante
          Navigator.pushReplacementNamed(context, '/participantes');
        }
      } else {
        // MENSAJES MÁS ESPECÍFICOS SEGÚN ROL
        String errorMsg = result['message'] ?? 'Error desconocido';
        
        if (_selectedRole == 'admin') {
          if (errorMsg.contains('no encontrado') || errorMsg.contains('inválido')) {
            errorMsg = '🔍 Código de administrador inválido.\n\nVerifica tu código e intenta de nuevo.';
          } else if (errorMsg.contains('inactivo')) {
            errorMsg = '⛔ Administrador inactivo.\n\nContacta al soporte técnico.';
          }
        } else {
          if (errorMsg.contains('ya está calificando')) {
            errorMsg = '⚠️ Este juez ya está calificando en otro dispositivo.\n\nEspera a que termine o contacta al administrador.';
          } else if (errorMsg.contains('inactivo')) {
            errorMsg = '⛔ Usuario inactivo.\n\nContacta al administrador para activar tu cuenta.';
          } else if (errorMsg.contains('no encontrado')) {
            errorMsg = '🔍 Código no encontrado.\n\nVerifica tu código e intenta de nuevo.';
          }
        }
        
        setState(() {
          _errorMessage = errorMsg;
        });
        
        print('❌ LOGIN FALLIDO: $errorMsg');
      }
    } catch (e) {
      print('❌ ERROR EN LOGIN: $e');
      setState(() {
        _errorMessage = '📡 Error de conexión.\n\nVerifica tu internet e intenta de nuevo.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = '';
      _codeController.clear();
      Future.delayed(const Duration(milliseconds: 300), () {
        _codeFocusNode.requestFocus();
      });
    });
    
    print('🎯 Rol seleccionado: $role');
  }

  void _goBack() {
    if (_selectedRole.isNotEmpty) {
      setState(() {
        _selectedRole = '';
        _codeController.clear();
        _errorMessage = '';
      });
      print('↩️ Regresando a selección de rol');
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedRole.isNotEmpty) 
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                )
              else
                const SizedBox(height: 8),

              const SizedBox(height: 20),

              Text(
                'Iniciar Sesión',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _selectedRole.isEmpty 
                    ? 'Selecciona tu rol' 
                    : _selectedRole == 'juez'
                        ? 'Ingresa tu código de juez'
                        : 'Ingresa tu código de administrador',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: AppColors.secondaryText,
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.errorColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.montserrat(
                            color: AppColors.errorColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _selectedRole.isEmpty 
                      ? _buildRoleSelection() 
                      : _buildCodeForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoleButton(
            title: 'SOY JUEZ',
            subtitle: 'Acceso para miembros del jurado',
            icon: Icons.gavel_rounded,
            color: AppColors.accentColor,
            onTap: () => _selectRole('juez'),
          ),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          _buildRoleButton(
            title: 'SOY ADMINISTRADOR',
            subtitle: 'Control total del sistema',
            icon: Icons.admin_panel_settings_rounded,
            color: AppColors.primaryColor,
            onTap: () => _selectRole('admin'),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.borderColor.withOpacity(0.5),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o',
            style: TextStyle(
              color: AppColors.hintText,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.borderColor.withOpacity(0.5),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: AppColors.cardBackground,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeForm() {
    final isJudge = _selectedRole == 'juez';
    final hintText = isJudge ? 'Ej: 1200' : 'Ej: ADMIN001';

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isJudge 
                    ? AppColors.accentColor.withOpacity(0.1)
                    : AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isJudge ? AppColors.accentColor : AppColors.primaryColor,
                  width: 3,
                ),
              ),
              child: Icon(
                isJudge ? Icons.gavel_rounded : Icons.admin_panel_settings_rounded,
                size: 45,
                color: isJudge ? AppColors.accentColor : AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isJudge ? 'JUEZ' : 'ADMINISTRADOR',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isJudge ? AppColors.accentColor : AppColors.primaryColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            TextFormField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.montserrat(color: AppColors.hintText),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isJudge ? AppColors.accentColor : AppColors.primaryColor,
                    width: 2.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu código';
                }
                return null;
              },
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isJudge ? AppColors.accentColor : AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'INGRESAR',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.lock_open_rounded),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isJudge
                  ? 'Usa el código asignado por el administrador'
                  : 'Usa el código de administrador del sistema',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: AppColors.hintText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}