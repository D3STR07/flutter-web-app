import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/etapa_model.dart';
import '../../../data/models/criterio_model.dart';
import '../../../data/models/calificacion_model.dart';
import '../../../service/etapa_service.dart';
import '../../../service/criterio_service.dart';
import '../../../service/calificacion_service.dart';
import '../../../service/user_session.dart';
import '../../../utils/constants/app_colors.dart';

class CalificarEtapaScreen extends StatefulWidget {
  final String etapaId;
  final String participanteId;
  final String participanteNombre;

  const CalificarEtapaScreen({
    super.key,
    required this.etapaId,
    required this.participanteId,
    required this.participanteNombre,
  });

  @override
  State<CalificarEtapaScreen> createState() => _CalificarEtapaScreenState();
}

class _CalificarEtapaScreenState extends State<CalificarEtapaScreen> {
  final EtapaService _etapaService = EtapaService();
  final CriterioService _criterioService = CriterioService();
  final CalificacionService _calificacionService = CalificacionService();
  
  Etapa? _etapa;
  List<Criterio> _criterios = [];
  Map<String, double> _puntajes = {};
  Map<String, String> _comentarios = {};
  bool _cargando = true;
  bool _guardando = false;
  double _totalParcial = 0.0;
  String? _errorMessage;
  String? _debugInfo;

  // Colores
  final Color _rosaOro = const Color(0xFFE8B4B8);
  final Color _dorado = const Color(0xFFD4AF37);
  final Color _blancoMarfil = const Color(0xFFF8F4E6);
  final Color _grisPerla = const Color(0xFFD8D8D8);
  final Color _verdeEsmeralda = const Color(0xFF50C878);
  final Color _grisOscuro = const Color(0xFF2C2C2C);
  final Color _azulPlateado = const Color(0xFFA8C3D0);

  @override
  void initState() {
    super.initState();
    print('🚀 CalificarEtapaScreen iniciado');
    print('   Etapa ID recibido: ${widget.etapaId}');
    print('   Participante: ${widget.participanteNombre} (${widget.participanteId})');
    print('   Juez actual: ${UserSession.displayName}');
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    print('\n🔄 INICIANDO CARGA DE DATOS');
    
    setState(() {
      _cargando = true;
      _errorMessage = null;
      _debugInfo = null;
    });
    
    try {
      // 1. Cargar todas las etapas para debug
      print('📥 Paso 1: Cargando etapas...');
      final etapas = await _etapaService.getEtapas().first;
      print('   ✅ Etapas totales: ${etapas.length}');
      
      for (final e in etapas) {
        print('      🏷️ ${e.id}: ${e.name} (order: ${e.order})');
      }
      
      // 2. Buscar la etapa específica
      print('\n📥 Paso 2: Buscando etapa específica...');
      print('   Buscando etapa con ID: ${widget.etapaId}');
      
      _etapa = etapas.firstWhere(
        (e) => e.id == widget.etapaId,
        orElse: () {
          print('   ❌ No encontrada por ID, buscando por nombre...');
          // Buscar por nombre si no encuentra por ID
          for (final e in etapas) {
            if (e.name.toLowerCase().contains(widget.etapaId.toLowerCase()) ||
                widget.etapaId.toLowerCase().contains(e.name.toLowerCase())) {
              print('   ✅ Encontrada por nombre: ${e.name} (ID: ${e.id})');
              return e;
            }
          }
          throw Exception('Etapa no encontrada');
        },
      );
      
      print('   ✅ Etapa encontrada: ${_etapa!.name} (ID: ${_etapa!.id})');
      
      // 3. Cargar criterios
      print('\n📥 Paso 3: Cargando criterios...');
      print('   Solicitando criterios para etapa ID: ${_etapa!.id}');
      
      _criterios = await _criterioService.getCriteriosDeEtapa(_etapa!.id);
      print('   ✅ Criterios recibidos: ${_criterios.length}');
      
      if (_criterios.isEmpty) {
        _debugInfo = 'No hay criterios en stages/${_etapa!.id}/questions';
        print('   ⚠️ $_debugInfo');
        throw Exception('Esta etapa no tiene criterios configurados');
      }
      
      // Mostrar criterios cargados
      for (final c in _criterios) {
        print('      📋 ${c.order}. ${c.text} (max: ${c.maxScore})');
      }
      
      // 4. Cargar calificaciones existentes
      print('\n📥 Paso 4: Cargando calificaciones existentes...');
      await _cargarCalificacionesExistentes();
      
      print('\n✅ CARGA COMPLETADA EXITOSAMENTE');
      print('   Etapa: ${_etapa!.name}');
      print('   Criterios: ${_criterios.length}');
      print('   Puntajes cargados: ${_puntajes.length}');
      
      setState(() {
        _cargando = false;
        _debugInfo = 'Etapa: ${_etapa!.name} | Criterios: ${_criterios.length}';
      });
      
    } catch (e) {
      print('\n❌ ERROR EN CARGA: $e');
      print('   Stack trace: ${e.toString()}');
      
      setState(() {
        _cargando = false;
        _errorMessage = e.toString();
        _debugInfo = 'Error: $e';
      });
    }
  }

  Future<void> _cargarCalificacionesExistentes() async {
    try {
      print('   🔍 Buscando calificaciones existentes...');
      final calificaciones = await _calificacionService
          .getCalificacionesJuezParticipante(
            participanteId: widget.participanteId,
            etapaId: _etapa!.id,
          )
          .first;
      
      print('   ✅ Calificaciones encontradas: ${calificaciones.length}');
      
      for (final calificacion in calificaciones) {
        _puntajes[calificacion.criterioId] = calificacion.puntaje;
        if (calificacion.comentario != null && calificacion.comentario!.isNotEmpty) {
          _comentarios[calificacion.criterioId] = calificacion.comentario!;
        }
        print('      📝 ${calificacion.criterioId}: ${calificacion.puntaje}');
      }
      
      _calcularTotal();
    } catch (e) {
      print('   ⚠️ Error cargando calificaciones: $e');
    }
  }

  void _calcularTotal() {
    _totalParcial = _puntajes.values.fold(0.0, (sum, puntaje) => sum + puntaje);
  }

  void _actualizarPuntaje(String criterioId, double puntaje) {
    setState(() {
      _puntajes[criterioId] = puntaje;
      _calcularTotal();
    });
  }

  void _actualizarComentario(String criterioId, String comentario) {
    setState(() {
      if (comentario.trim().isEmpty) {
        _comentarios.remove(criterioId);
      } else {
        _comentarios[criterioId] = comentario;
      }
    });
  }

  bool get _formularioCompleto {
    return _puntajes.length == _criterios.length;
  }

  Future<void> _guardarCalificaciones() async {
    if (!_formularioCompleto) {
      _mostrarError('Por favor, califica todos los criterios antes de guardar');
      return;
    }

    setState(() => _guardando = true);

    try {
      print('\n💾 GUARDANDO CALIFICACIONES...');
      
      for (final criterio in _criterios) {
        final calificacion = Calificacion.createNew(
          juezId: UserSession.firebaseId!,
          participanteId: widget.participanteId,
          etapaId: _etapa!.id,
          criterioId: criterio.id,
          puntaje: _puntajes[criterio.id]!,
          comentario: _comentarios[criterio.id],
        );

        print('   📝 Guardando: ${criterio.text} = ${_puntajes[criterio.id]}');
        await _calificacionService.guardarCalificacionFirebase(calificacion);
      }

      print('✅ TODAS LAS CALIFICACIONES GUARDADAS');
      _mostrarExito('✅ Calificaciones guardadas exitosamente');
      
      // Regresar después de 1.5 segundos
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });

    } catch (e) {
      print('❌ ERROR AL GUARDAR: $e');
      _mostrarError('❌ Error al guardar: $e');
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: _verdeEsmeralda,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _grisOscuro,
        title: Text('Información de Debug', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Etapa ID recibido:', style: TextStyle(color: _grisPerla)),
              Text(widget.etapaId, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 12),
              Text('Etapa encontrada:', style: TextStyle(color: _grisPerla)),
              Text('${_etapa?.name ?? "No"} (ID: ${_etapa?.id ?? "N/A"})', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 12),
              Text('Criterios cargados:', style: TextStyle(color: _grisPerla)),
              Text('${_criterios.length}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 12),
              Text('Participante:', style: TextStyle(color: _grisPerla)),
              Text('${widget.participanteNombre} (${widget.participanteId})', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 12),
              Text('Juez actual:', style: TextStyle(color: _grisPerla)),
              Text(UserSession.displayName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              
              if (_debugInfo != null) ...[
                const SizedBox(height: 12),
                Text('Info adicional:', style: TextStyle(color: _grisPerla)),
                Text(_debugInfo!, style: TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: _rosaOro)),
          ),
          TextButton(
            onPressed: () {
              _cargarDatos();
              Navigator.pop(context);
            },
            child: Text('Recargar', style: TextStyle(color: _verdeEsmeralda)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grisOscuro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: _blancoMarfil, size: 28),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calificar Etapa',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _blancoMarfil,
              ),
            ),
            Text(
              _etapa?.name ?? 'Cargando...',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: _grisPerla,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _mostrarDebugInfo,
            icon: Icon(Icons.bug_report_rounded, color: _grisPerla),
            tooltip: 'Info de debug',
          ),
        ],
      ),
      body: _cargando
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError(_errorMessage!)
              : _criterios.isEmpty
                  ? _buildSinCriterios()
                  : _buildContenido(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _dorado, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Cargando criterios...',
            style: GoogleFonts.montserrat(color: _grisPerla, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'Etapa: ${_etapa?.name ?? widget.etapaId}',
            style: GoogleFonts.montserrat(color: _rosaOro, fontSize: 14),
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
            Icon(Icons.error_outline_rounded, size: 60, color: _rosaOro),
            const SizedBox(height: 20),
            Text(
              'Error al cargar',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                error.length > 200 ? '${error.substring(0, 200)}...' : error,
                style: GoogleFonts.montserrat(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _cargarDatos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rosaOro,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Reintentar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _grisPerla,
                    side: BorderSide(color: _grisPerla),
                  ),
                  child: Text('Volver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinCriterios() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 80,
              color: _grisPerla.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay criterios disponibles',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Esta etapa no tiene criterios de evaluación configurados en Firebase.',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: _grisPerla,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ruta en Firebase: stages/${_etapa?.id ?? widget.etapaId}/questions/',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: _dorado,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cargarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: _rosaOro,
                foregroundColor: Colors.white,
              ),
              child: Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    return Column(
      children: [
        // Header informativo
        _buildHeader(),
        
        // Resumen parcial
        _buildResumen(),
        
        // Lista de criterios
        Expanded(
          child: _buildListaCriterios(),
        ),
        
        // Botón guardar
        _buildBotonGuardar(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoMarfil.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grisPerla.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _etapa!.colorFlutter.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _etapa!.colorFlutter, width: 2),
            ),
            child: Icon(
              Icons.person_rounded,
              color: _etapa!.colorFlutter,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.participanteNombre,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _etapa!.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: _etapa!.colorFlutter,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_etapa!.subtitle != null && _etapa!.subtitle!.isNotEmpty)
                  Text(
                    _etapa!.subtitle!,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _grisPerla,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final completados = _puntajes.length;
    final total = _criterios.length;
    final promedio = total > 0 ? _totalParcial / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _blancoMarfil.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grisPerla.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progreso',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: _grisPerla,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completados/$total criterios',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: total > 0 ? completados / total : 0,
                  backgroundColor: _grisOscuro,
                  color: completados == total ? _verdeEsmeralda : _dorado,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text(
                'Total Parcial',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: _grisPerla,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _totalParcial.toStringAsFixed(1),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _dorado,
                ),
              ),
              Text(
                'Promedio: ${promedio.toStringAsFixed(1)}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _grisPerla,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaCriterios() {
    return RefreshIndicator(
      backgroundColor: _grisOscuro,
      color: _dorado,
      onRefresh: () async {
        await _cargarDatos();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _criterios.length,
        itemBuilder: (context, index) {
          final criterio = _criterios[index];
          return _buildTarjetaCriterio(criterio);
        },
      ),
    );
  }

  Widget _buildTarjetaCriterio(Criterio criterio) {
    final puntajeActual = _puntajes[criterio.id] ?? 0.0;
    final comentarioActual = _comentarios[criterio.id] ?? '';
    final estaCalificado = _puntajes.containsKey(criterio.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _blancoMarfil.withOpacity(estaCalificado ? 0.05 : 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: estaCalificado ? _verdeEsmeralda.withOpacity(0.3) : _grisPerla.withOpacity(0.2),
              width: estaCalificado ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(estaCalificado ? 0.15 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header del criterio
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _azulPlateado.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: _azulPlateado),
                      ),
                      child: Center(
                        child: Text(
                          (criterio.order + 1).toString(),
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            color: _azulPlateado,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            criterio.text,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Puntaje máximo: ${criterio.maxScore.toInt()}',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: _grisPerla,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (estaCalificado)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _verdeEsmeralda.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _verdeEsmeralda),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: _verdeEsmeralda),
                            const SizedBox(width: 6),
                            Text(
                              '${puntajeActual.toStringAsFixed(1)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _verdeEsmeralda,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Slider para puntaje
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Puntaje:',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: _grisPerla,
                          ),
                        ),
                        Text(
                          '${puntajeActual.toStringAsFixed(1)} / ${criterio.maxScore.toInt()}',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: estaCalificado ? _verdeEsmeralda : _dorado,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                          elevation: 4,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: _dorado,
                        inactiveTrackColor: _grisPerla.withOpacity(0.3),
                        thumbColor: Colors.white,
                        overlayColor: _dorado.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: puntajeActual,
                        min: 0.0,
                        max: criterio.maxScore,
                        divisions: (criterio.maxScore * 2).toInt(), // 0.5 incrementos
                        label: puntajeActual.toStringAsFixed(1),
                        onChanged: (value) {
                          _actualizarPuntaje(criterio.id, value);
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0.0',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: _grisPerla,
                          ),
                        ),
                        Text(
                          criterio.maxScore.toStringAsFixed(0),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: _grisPerla,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Comentario (opcional)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment_rounded, size: 16, color: _grisPerla),
                        const SizedBox(width: 8),
                        Text(
                          'Comentario (opcional)',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: _grisPerla,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${comentarioActual.length}/500',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: comentarioActual.length > 500 
                                ? Colors.red 
                                : _grisPerla,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      maxLength: 500,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escribe aquí tus observaciones...',
                        hintStyle: GoogleFonts.montserrat(color: _grisPerla),
                        filled: true,
                        fillColor: _blancoMarfil.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        counterStyle: TextStyle(color: _grisPerla),
                      ),
                      onChanged: (value) {
                        _actualizarComentario(criterio.id, value);
                      },
                      controller: TextEditingController(text: comentarioActual),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonGuardar() {
    final estaCompleto = _formularioCompleto;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _grisOscuro,
        border: Border(
          top: BorderSide(color: _grisPerla.withOpacity(0.2)),
        ),
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: estaCompleto && !_guardando ? _guardarCalificaciones : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: estaCompleto ? _verdeEsmeralda : _grisPerla.withOpacity(0.3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: _guardando
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded),
                    const SizedBox(width: 12),
                    Text(
                      estaCompleto ? 'GUARDAR CALIFICACIONES' : 'COMPLETA TODOS LOS CRITERIOS',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: estaCompleto ? 16 : 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}