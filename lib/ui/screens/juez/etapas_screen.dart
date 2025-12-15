import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/etapa_model.dart';
import '../../../service/etapa_service.dart';
import '../../../service/user_session.dart';
import '../../../utils/constants/app_colors.dart';
// Importar la pantalla de calificación
import 'calificar_etapa_screen.dart'; // Asegúrate de que la ruta sea correcta

class EtapasScreen extends StatefulWidget {
  const EtapasScreen({super.key});

  @override
  State<EtapasScreen> createState() => _EtapasScreenState();
}

class _EtapasScreenState extends State<EtapasScreen> {
  final EtapaService _etapaService = EtapaService();
  Etapa? _etapaActiva;
  bool _cargando = false;

  // Colores elegantes para certamen de belleza
  final Color _rosaOro = const Color(0xFFE8B4B8); // Rosa dorado suave
  final Color _dorado = const Color(0xFFD4AF37); // Dorado elegante
  final Color _blancoMarfil = const Color(0xFFF8F4E6); // Blanco marfil
  final Color _grisPerla = const Color(0xFFD8D8D8); // Gris perla
  final Color _azulPlateado = const Color(0xFFA8C3D0); // Azul plateado
  final Color _vino = const Color(0xFF722F37); // Vino tinto elegante
  final Color _grisOscuro = const Color(0xFF2C2C2C); // Gris oscuro
  final Color _verdeEsmeralda = const Color(0xFF50C878); // Verde esmeralda

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grisOscuro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Etapas del Certamen',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              UserSession.isAdmin ? 'Panel Administrativo' : 'Seguimiento del Evento',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: _grisPerla,
                letterSpacing: 1,
              ),
            ),
            // Mostrar participante actual si es juez
            if (UserSession.isJudge && UserSession.hasSelectedParticipante)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Evaluando: ${UserSession.selectedParticipanteNombre}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: _rosaOro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          // BOTÓN PARA CAMBIAR PARTICIPANTE (SOLO PARA JUECES)
          if (UserSession.isJudge && UserSession.hasSelectedParticipante)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: _confirmarCambiarParticipante,
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _rosaOro.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _rosaOro, width: 1.5),
                  ),
                  child: Icon(
                    Icons.switch_account_rounded,
                    color: _rosaOro,
                    size: 20,
                  ),
                ),
                tooltip: 'Cambiar participante',
              ),
            ),
          
          if (UserSession.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: _dorado,
                size: 24,
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _grisOscuro,
              const Color(0xFF3A3A3A),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header con info de etapa activa
            _buildHeaderEtapaActiva(),
            
            // Contador de etapas
            _buildContadorEtapas(),
            
            // Lista de etapas
            Expanded(
              child: StreamBuilder<List<Etapa>>(
                stream: _etapaService.getEtapas(),
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

                  final etapas = snapshot.data!;
                  
                  // Ordenar por order
                  etapas.sort((a, b) => a.order.compareTo(b.order));
                  
                  return _buildListaEtapas(etapas);
                },
              ),
            ),
          ],
        ),
      ),
      // Botón flotante para cambiar participante (opcional)
      floatingActionButton: UserSession.isJudge && UserSession.hasSelectedParticipante
          ? FloatingActionButton.extended(
              onPressed: _confirmarCambiarParticipante,
              backgroundColor: _rosaOro,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              icon: Icon(Icons.switch_account_rounded),
              label: Text(
                'CAMBIAR',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ========== MÉTODO MODIFICADO PARA MANEJAR TAP EN ETAPA ==========
  Future<void> _manejarTapEtapa(Etapa etapa) async {
    // Si es JUEZ y tiene un participante seleccionado, navegar a calificar
    if (UserSession.isJudge && UserSession.hasSelectedParticipante) {
      _navegarACalificarEtapa(etapa);
      return;
    }
    
    // Si es ADMIN, mantener la lógica original
    if (!UserSession.isAdmin) {
      _mostrarInfoEtapa(etapa);
      return;
    }

    if (etapa.isActive) {
      await _confirmarFinalizarEtapa();
    } else if (etapa.estaCerrada) {
      await _confirmarActivarEtapa(etapa);
    } else if (etapa.isFinished) {
      await _confirmarReabrirEtapa(etapa);
    }
  }

  // ========== NUEVO MÉTODO PARA NAVEGAR A CALIFICAR ETAPA ==========
  void _navegarACalificarEtapa(Etapa etapa) {
    // Verificar si la etapa está activa
    if (!etapa.isActive) {
      _mostrarDialogoEtapaNoDisponible(etapa);
      return;
    }

    // Navegar a la pantalla de calificación
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalificarEtapaScreen(
          etapaId: etapa.id,
          participanteId: UserSession.selectedParticipanteId!,
          participanteNombre: UserSession.selectedParticipanteNombre!,
        ),
      ),
    );
  }

  // ========== NUEVO MÉTODO PARA MOSTRAR DIÁLOGO CUANDO LA ETAPA NO ESTÁ DISPONIBLE ==========
  void _mostrarDialogoEtapaNoDisponible(Etapa etapa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _rosaOro.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _rosaOro, width: 2),
              ),
              child: Icon(
                Icons.lock_rounded,
                color: _rosaOro,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Etapa No Disponible',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La etapa "${etapa.name}" no está disponible para calificación.',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blancoMarfil.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _rosaOro.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconoEstado(etapa.status),
                    size: 20,
                    color: _getColorEstado(etapa.status),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Estado: ${etapa.estadoTexto.toUpperCase()}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _getColorEstado(etapa.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solo puedes calificar etapas que estén marcadas como ACTIVAS.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _grisPerla,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _grisPerla,
            ),
            child: Text(
              'ENTENDIDO',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== MODIFICAR buildTarjetaEtapa para mostrar botón de calificar ==========
  Widget _buildTarjetaEtapa(Etapa etapa, bool esActiva, bool esUltima) {
    final color = etapa.colorFlutter;
    final opacidad = etapa.estaCerrada ? 0.4 : 1.0;
    final estaFinalizada = etapa.isFinished;
    
    // Determinar si se debe mostrar el botón de calificar
    final mostrarBotonCalificar = UserSession.isJudge && 
                                  UserSession.hasSelectedParticipante && 
                                  etapa.isActive;
    
    return Container(
      margin: EdgeInsets.only(bottom: esUltima ? 0 : 16),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _manejarTapEtapa(etapa),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: esActiva
                    ? [color.withOpacity(0.2), _grisOscuro.withOpacity(0.8)]
                    : [_blancoMarfil.withOpacity(0.03), _blancoMarfil.withOpacity(0.01)],
              ),
              border: Border.all(
                color: esActiva
                    ? color
                    : _grisPerla.withOpacity(0.3),
                width: esActiva ? 2 : 1,
              ),
              boxShadow: esActiva
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Número de etapa con diseño elegante
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: esActiva
                              ? LinearGradient(
                                  colors: [_dorado, _rosaOro],
                                )
                              : LinearGradient(
                                  colors: [
                                    _grisPerla.withOpacity(0.2),
                                    _azulPlateado.withOpacity(0.2)
                                  ],
                                ),
                          border: Border.all(
                            color: esActiva ? _dorado : _grisPerla.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: esActiva
                              ? [
                                  BoxShadow(
                                    color: _dorado.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (estaFinalizada)
                              Icon(
                                Icons.check_circle_rounded,
                                color: _verdeEsmeralda,
                                size: 28,
                              ),
                            if (!estaFinalizada)
                              Text(
                                etapa.order.toString(),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: esActiva ? Colors.white : _grisPerla,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Información de la etapa
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        etapa.name,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(opacidad),
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (etapa.subtitle != null && etapa.subtitle!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          etapa.subtitle!,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 13,
                                            color: _grisPerla.withOpacity(opacidad),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getColorEstado(etapa.status)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getColorEstado(etapa.status),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    etapa.estadoTexto.toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _getColorEstado(etapa.status),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Row(
                              children: [
                                _buildEtiquetaInfo(
                                  Icons.category_rounded,
                                  etapa.type == 'pasarela' ? 'Pasarela' : etapa.type,
                                  _azulPlateado,
                                ),
                                const SizedBox(width: 16),
                                if (etapa.maxScore != null)
                                  _buildEtiquetaInfo(
                                    Icons.star_rounded,
                                    '${etapa.maxScore} pts',
                                    _dorado,
                                  ),
                                if (UserSession.isAdmin) ...[
                                  const SizedBox(width: 16),
                                  _buildEtiquetaInfo(
                                    _getIconoAccion(etapa),
                                    _getTextoAccion(etapa),
                                    _getColorAccion(etapa),
                                  ),
                                ],
                              ],
                            ),
                            
                            // Botón de calificar para jueces (solo si etapa está activa)
                            if (mostrarBotonCalificar) ...[
                              const SizedBox(height: 16),
                              Container(
                                height: 40,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_verdeEsmeralda, const Color(0xFF90EE90)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _verdeEsmeralda.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _navegarACalificarEtapa(etapa),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.star_rounded, size: 18, color: Colors.white),
                                        const SizedBox(width: 10),
                                        Text(
                                          'CALIFICAR AHORA',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            // Línea de progreso para etapas finalizadas
                            if (etapa.isFinished) ...[
                              const SizedBox(height: 16),
                              Container(
                                height: 4,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _grisPerla.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [_verdeEsmeralda, const Color(0xFF90EE90)],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Indicador de etapa activa
                if (esActiva)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dorado,
                        boxShadow: [
                          BoxShadow(
                            color: _dorado.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... EL RESTO DEL CÓDIGO SE MANTIENE IGUAL (solo copia todo desde aquí hacia abajo) ...

  Widget _buildHeaderEtapaActiva() {
    return StreamBuilder<Etapa?>(
      stream: _etapaService.getEtapaActiva(),
      builder: (context, snapshot) {
        final etapa = snapshot.data;
        _etapaActiva = etapa;
        
        if (etapa == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _blancoMarfil.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _rosaOro.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _rosaOro.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _rosaOro, width: 2),
                  ),
                  child: Icon(
                    Icons.pause_circle_filled_rounded,
                    color: _rosaOro,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certamen en Pausa',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _blancoMarfil,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Activa una etapa para comenzar el evento',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: _grisPerla,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                etapa.colorFlutter.withOpacity(0.15),
                _grisOscuro.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: etapa.colorFlutter,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: etapa.colorFlutter.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_dorado, _rosaOro],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _dorado.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ETAPA EN CURSO',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _dorado,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                etapa.name.toUpperCase(),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (etapa.subtitle != null && etapa.subtitle!.isNotEmpty)
                Text(
                  etapa.subtitle!,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    color: _grisPerla,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.category_rounded,
                    'Tipo',
                    etapa.type == 'pasarela' ? 'Pasarela' : etapa.type,
                  ),
                  const SizedBox(width: 12),
                  if (etapa.maxScore != null)
                    _buildInfoChip(
                      Icons.star_border_rounded,
                      'Puntaje',
                      '${etapa.maxScore} pts',
                    ),
                ],
              ),
              if (UserSession.isAdmin && etapa.isActive) ...[
                const SizedBox(height: 20),
                Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_vino, const Color(0xFF8B3A47)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _vino.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: _confirmarFinalizarEtapa,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flag_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            'FINALIZAR ETAPA ACTUAL',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildContadorEtapas() {
    return StreamBuilder<List<Etapa>>(
      stream: _etapaService.getEtapas(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        final etapas = snapshot.data!;
        final completadas = etapas.where((e) => e.isFinished).length;
        final total = etapas.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Progreso del Certamen',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _grisPerla,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _blancoMarfil.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _grisPerla.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completadas/$total Etapas Completadas',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _blancoMarfil,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _grisOscuro,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: total > 0 ? completadas / total : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_dorado, _rosaOro],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _dorado.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _dorado),
                      ),
                      child: Text(
                        '${((total > 0 ? completadas / total : 0) * 100).round()}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _dorado,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _dorado,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando etapas...',
            style: GoogleFonts.montserrat(
              color: _grisPerla,
              fontSize: 14,
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _rosaOro.withOpacity(0.1),
                border: Border.all(color: _rosaOro, width: 2),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: _rosaOro,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Error al cargar etapas',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              style: GoogleFonts.montserrat(
                color: _grisPerla,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_azulPlateado, const Color(0xFFB8D3E0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => setState(() {}),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    'REINTENTAR',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      color: _grisOscuro,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_rosaOro.withOpacity(0.2), _dorado.withOpacity(0.2)],
                ),
                border: Border.all(color: _grisPerla.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 60,
                color: _grisPerla,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Certamen por Comenzar',
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _blancoMarfil,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Las etapas del certamen se mostrarán aquí una vez configuradas',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                color: _grisPerla,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contacta al administrador del evento',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _dorado,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaEtapas(List<Etapa> etapas) {
    return RefreshIndicator(
      backgroundColor: _grisOscuro,
      color: _dorado,
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: etapas.length,
        itemBuilder: (context, index) {
          final etapa = etapas[index];
          final esActiva = etapa.isActive;
          final esUltima = index == etapas.length - 1;
          
          return _buildTarjetaEtapa(etapa, esActiva, esUltima);
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _blancoMarfil.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _grisPerla.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _grisPerla),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: _grisPerla,
                ),
              ),
              Text(
                valor,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _blancoMarfil,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEtiquetaInfo(IconData icon, String texto, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          texto,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getColorEstado(String status) {
    switch (status) {
      case 'active':
        return _verdeEsmeralda;
      case 'finished':
        return _azulPlateado;
      case 'closed':
        return _rosaOro;
      default:
        return _grisPerla;
    }
  }

  IconData _getIconoEstado(String status) {
    switch (status) {
      case 'active':
        return Icons.play_arrow_rounded;
      case 'finished':
        return Icons.check_circle_rounded;
      case 'closed':
        return Icons.lock_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  IconData _getIconoAccion(Etapa etapa) {
    if (etapa.isActive) return Icons.flag_rounded;
    if (etapa.isFinished) return Icons.restart_alt_rounded;
    if (etapa.estaCerrada) return Icons.play_arrow_rounded;
    return Icons.help_rounded;
  }

  String _getTextoAccion(Etapa etapa) {
    if (etapa.isActive) return 'Finalizar';
    if (etapa.isFinished) return 'Reabrir';
    if (etapa.estaCerrada) return 'Activar';
    return 'Ver';
  }

  Color _getColorAccion(Etapa etapa) {
    if (etapa.isActive) return _vino;
    if (etapa.isFinished) return _azulPlateado;
    if (etapa.estaCerrada) return _verdeEsmeralda;
    return _grisPerla;
  }

  Future<void> _confirmarCambiarParticipante() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_rosaOro, _dorado]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.switch_account_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cambiar Participante',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de cambiar de participante?',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Actualmente evaluando a:',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _grisPerla,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blancoMarfil.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _rosaOro.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 16, color: _rosaOro),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      UserSession.selectedParticipanteNombre ?? 'Sin nombre',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Volverás a la pantalla de selección para elegir otro participante.',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: _grisPerla,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _grisPerla,
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_rosaOro, const Color(0xFFF5C6CB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.switch_account_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CAMBIAR',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _cambiarParticipante();
    }
  }

  void _cambiarParticipante() {
    // Limpiar la selección actual
    UserSession.clearSelectedParticipante();
    
    // Mostrar mensaje de confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.switch_account_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Cambiando de participante...',
              style: GoogleFonts.montserrat(),
            ),
          ],
        ),
        backgroundColor: _rosaOro,
        duration: const Duration(milliseconds: 800),
      ),
    );
    
    // Navegar a pantalla de selección después de un breve delay
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.pushReplacementNamed(context, '/participantes');
    });
  }

  Future<void> _confirmarActivarEtapa(Etapa etapa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_dorado, _rosaOro]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Activar Etapa',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Activar la etapa "${etapa.name}"?\n\n'
          'Esto finalizará automáticamente cualquier etapa '
          'que esté actualmente activa.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: _grisPerla,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _grisPerla,
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_dorado, _rosaOro]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'ACTIVAR ETAPA',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      final exito = await _etapaService.activarEtapa(etapa.id);
      setState(() => _cargando = false);
      
      if (exito && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Etapa "${etapa.name}" activada',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: _verdeEsmeralda,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmarFinalizarEtapa() async {
    if (_etapaActiva == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_vino, const Color(0xFF8B3A47)]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Finalizar Etapa',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Finalizar la etapa "${_etapaActiva!.name}"?\n\n'
          'Los jueces ya no podrán calificar en esta etapa.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: _grisPerla,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _grisPerla,
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_vino, const Color(0xFF8B3A47)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'FINALIZAR',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      final exito = await _etapaService.finalizarEtapaActiva();
      setState(() => _cargando = false);
      
      if (exito && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Etapa "${_etapaActiva!.name}" finalizada',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: _verdeEsmeralda,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmarReabrirEtapa(Etapa etapa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_azulPlateado, const Color(0xFFB8D3E0)]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restart_alt_rounded,
                color: _grisOscuro,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Reabrir Etapa',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Reabrir la etapa "${etapa.name}"?\n\n'
          'Esta etapa volverá a estar disponible para calificaciones.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: _grisPerla,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _grisPerla,
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_azulPlateado, const Color(0xFFB8D3E0)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: _grisOscuro,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'REABRIR',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: _grisOscuro,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      final exito = await _etapaService.reabrirEtapa(etapa.id);
      setState(() => _cargando = false);
      
      if (exito && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Etapa "${etapa.name}" reabierta',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: _verdeEsmeralda,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _mostrarInfoEtapa(Etapa etapa) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _grisOscuro,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _grisPerla.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [etapa.colorFlutter, _rosaOro],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      etapa.order.toString(),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          etapa.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (etapa.subtitle != null && etapa.subtitle!.isNotEmpty)
                          Text(
                            etapa.subtitle!,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              color: _grisPerla,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getColorEstado(etapa.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getColorEstado(etapa.status)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconoEstado(etapa.status),
                      size: 16,
                      color: _getColorEstado(etapa.status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      etapa.estadoTexto.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _getColorEstado(etapa.status),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: _grisPerla.withOpacity(0.3)),
              const SizedBox(height: 20),
              _buildInfoItemDetalle(
                Icons.category_rounded,
                'Tipo de Etapa',
                etapa.type == 'pasarela' ? 'Pasarela' : etapa.type,
                _azulPlateado,
              ),
              const SizedBox(height: 16),
              if (etapa.maxScore != null)
                _buildInfoItemDetalle(
                  Icons.star_rounded,
                  'Puntaje Máximo',
                  '${etapa.maxScore} puntos',
                  _dorado,
                ),
              const SizedBox(height: 16),
              if (etapa.createdAt != null)
                _buildInfoItemDetalle(
                  Icons.calendar_month_rounded,
                  'Fecha de Creación',
                  '${etapa.createdAt!.day}/${etapa.createdAt!.month}/${etapa.createdAt!.year}',
                  _rosaOro,
                ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_dorado, _rosaOro]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _dorado.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text(
                      'ENTENDIDO',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItemDetalle(IconData icon, String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoMarfil.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grisPerla.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: _grisPerla,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}