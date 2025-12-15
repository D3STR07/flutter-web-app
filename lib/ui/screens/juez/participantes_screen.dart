import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/participante_model.dart';
import '../../../service/auth_service.dart';
import '../../../service/participante_service.dart';
import '../../../service/user_session.dart';
import '../../../utils/constants/app_colors.dart';

class ParticipantesScreen extends StatefulWidget {
  const ParticipantesScreen({super.key});

  @override
  State<ParticipantesScreen> createState() => _ParticipantesScreenState();
}

class _ParticipantesScreenState extends State<ParticipantesScreen> {
  final ParticipanteService _participanteService = ParticipanteService();
  final AuthService _authService = AuthService();
  late Stream<List<Participante>> _participantesStream;
  Map<String, bool> _estadosEvaluacion = {};
  bool _loadingEstados = false;

  @override
  void initState() {
    super.initState();
    _participantesStream = _participanteService.getParticipantesActivos();
  }

  Future<void> _actualizarEstados(List<Participante> participantes) async {
    if (participantes.isEmpty) return;

    setState(() => _loadingEstados = true);

    try {
      final estados = await _participanteService.getEstadosEvaluacion(
        participantes,
        UserSession.idInterno ?? '',
      );
      
      setState(() {
        _estadosEvaluacion = estados;
        _loadingEstados = false;
      });
    } catch (e) {
      print('❌ Error actualizando estados: $e');
      setState(() => _loadingEstados = false);
    }
  }

  Future<void> _confirmarLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: AppColors.accentColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Cerrar Sesión',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?\n\n'
          'Se liberará tu usuario para que otros jueces puedan usarlo.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondaryText,
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'SÍ, CERRAR',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _realizarLogout();
    }
  }

  Future<void> _realizarLogout() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cerrando sesión...',
              style: GoogleFonts.montserrat(),
            ),
          ],
        ),
        backgroundColor: AppColors.accentColor,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _authService.logout();
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/login', 
          (route) => false
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Sesión cerrada exitosamente',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('❌ Error en logout: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error al cerrar sesión',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navegarAEtapas(Participante participante) {
    print('==========================================');
    print('🎯 JUEZ SELECCIONÓ PARTICIPANTE');
    print('==========================================');
    print('👤 Juez: ${UserSession.displayName}');
    print('👑 Participante: ${participante.nombre}');
    print('🆔 ID Participante: ${participante.id}');
    print('🏷️ ID Interno: ${participante.idInterno}');
    print('⏰ Timestamp: ${DateTime.now()}');
    print('==========================================');
    
    // Guardar selección en UserSession
    UserSession.setSelectedParticipante(
      participanteId: participante.id,
      participanteNombre: participante.nombre,
    );
    
    // Navegar a pantalla de etapas
    Navigator.pushReplacementNamed(context, '/etapas');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Selecciona a quién evaluar',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Botón de diagnóstico y herramientas
          PopupMenuButton<String>(
            icon: Icon(Icons.bug_report, color: Colors.white),
            onSelected: (value) async {
              if (value == 'diagnostico') {
                await _participanteService.diagnosticarProblema();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Diagnóstico ejecutado - Ver consola'),
                    backgroundColor: AppColors.accentColor,
                    duration: Duration(seconds: 3),
                  ),
                );
                
              } else if (value == 'limpiar_inactivos') {
                // Diagnosticar primero
                await _participanteService.diagnosticarProblema();
                
                // Preguntar confirmación
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('¿Eliminar inactivos?'),
                      ],
                    ),
                    content: Text('Se eliminarán los participantes inactivos del cache local.\n\nEsta acción no afecta Firebase.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Eliminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _participanteService.limpiarInactivosCache();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Inactivos eliminados del cache'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refrescar la lista
                  setState(() {
                    _participantesStream = _participanteService.getParticipantesActivos();
                  });
                }
                
              } else if (value == 'forzar_actualizacion') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        SizedBox(width: 12),
                        Text('Actualizando desde Firebase...'),
                      ],
                    ),
                    backgroundColor: AppColors.accentColor,
                  ),
                );
                
                await _participanteService.forzarActualizacionDesdeFirebase();
                
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Cache actualizado desde Firebase'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Refrescar
                setState(() {
                  _participantesStream = _participanteService.getParticipantesActivos();
                });
                
              } else if (value == 'ver_todos') {
                // Ver todos sin filtro (para debug)
                final snapshot = await FirebaseFirestore.instance
                    .collection('participantes')
                    .get();
                    
                print('📋 TODOS LOS PARTICIPANTES (sin filtro):');
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  print('   ${data['idInterno']}: ${data['nombre']} - activo: ${data['activo']}');
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ver consola para detalles'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'diagnostico',
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.accentColor),
                    SizedBox(width: 8),
                    Text('Ejecutar Diagnóstico'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'limpiar_inactivos',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Eliminar Inactivos Cache'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'forzar_actualizacion',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Forzar Actualización Firebase'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ver_todos',
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Ver Todos (Debug)'),
                  ],
                ),
              ),
            ],
          ),
          
          // Botón de logout
          IconButton(
            onPressed: _confirmarLogout,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentColor,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.accentColor,
              ),
            ),
            tooltip: 'Cerrar Sesión',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderJuez(),
          Expanded(
            child: StreamBuilder<List<Participante>>(
              stream: _participantesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }

                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmpty();
                }

                final participantes = snapshot.data!;
                
                if (_estadosEvaluacion.length != participantes.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _actualizarEstados(participantes);
                  });
                }

                return _buildListaParticipantes(participantes);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderJuez() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: AppColors.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UserSession.displayName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Juez calificando',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_loadingEstados) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accentColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando participantes...',
            style: GoogleFonts.montserrat(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Error al cargar',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              style: GoogleFonts.montserrat(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _participantesStream = _participanteService.getParticipantesActivos();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 80,
            color: AppColors.secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay participantes',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Agrega participantes desde el panel de administración',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListaParticipantes(List<Participante> participantes) {
    return RefreshIndicator(
      backgroundColor: AppColors.primaryBackground,
      color: AppColors.accentColor,
      onRefresh: () async {
        setState(() {
          _participantesStream = _participanteService.getParticipantesActivos();
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: participantes.length,
        itemBuilder: (context, index) {
          final participante = participantes[index];
          final yaEvaluada = _estadosEvaluacion[participante.id] ?? false;
          
          return _buildTarjetaParticipante(participante, yaEvaluada);
        },
      ),
    );
  }

  Widget _buildTarjetaParticipante(Participante participante, bool yaEvaluada) {
    // Verificar si el participante está activo (defensa adicional)
    final estaActivo = participante.activo;
    
    if (!estaActivo) {
      // No debería llegar aquí si todo funciona correctamente
      print('⚠️ PARTICIPANTE INACTIVO EN LISTA: ${participante.nombre}');
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: !estaActivo
            ? AppColors.cardBackground.withOpacity(0.3)
            : yaEvaluada
                ? AppColors.cardBackground.withOpacity(0.7)
                : AppColors.cardBackground,
        elevation: 2,
        child: InkWell(
          onTap: !estaActivo || yaEvaluada ? null : () => _navegarAEtapas(participante),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(participante, !estaActivo || yaEvaluada),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participante.displayName,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: !estaActivo
                              ? AppColors.secondaryText.withOpacity(0.5)
                              : yaEvaluada
                                  ? AppColors.secondaryText
                                  : Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        participante.idInterno.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: !estaActivo
                              ? AppColors.secondaryText.withOpacity(0.3)
                              : yaEvaluada
                                  ? AppColors.secondaryText.withOpacity(0.7)
                                  : AppColors.secondaryText,
                        ),
                      ),
                      if (!estaActivo) ...[
                        const SizedBox(height: 4),
                        Text(
                          'INACTIVO',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: AppColors.errorColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                !estaActivo
                    ? _buildEstadoInactivo()
                    : _buildEstado(yaEvaluada),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoInactivo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.errorColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: 14,
            color: AppColors.errorColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Inactivo',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Participante participante, bool yaEvaluada) {
    if (participante.fotoUrl != null && participante.fotoUrl!.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: yaEvaluada
                ? AppColors.secondaryText
                : AppColors.accentColor,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            participante.fotoUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.accentColor,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildAvatarPlaceholder(yaEvaluada);
            },
          ),
        ),
      );
    }
    
    return _buildAvatarPlaceholder(yaEvaluada);
  }

  Widget _buildAvatarPlaceholder(bool yaEvaluada) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: yaEvaluada
            ? AppColors.secondaryText.withOpacity(0.1)
            : AppColors.accentColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: yaEvaluada
              ? AppColors.secondaryText
              : AppColors.accentColor,
          width: 2,
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 30,
        color: yaEvaluada
            ? AppColors.secondaryText
            : AppColors.accentColor,
      ),
    );
  }

  Widget _buildEstado(bool yaEvaluada) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: yaEvaluada
            ? AppColors.successColor.withOpacity(0.1)
            : AppColors.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: yaEvaluada ? AppColors.successColor : AppColors.accentColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            yaEvaluada ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 14,
            color: yaEvaluada ? AppColors.successColor : AppColors.accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            yaEvaluada ? 'Evaluada' : 'Pendiente',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: yaEvaluada ? AppColors.successColor : AppColors.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}