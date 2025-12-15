import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Definiciones de colecciones
const String collectionParticipantes = 'participantes';
const String collectionCalificaciones = 'calificaciones';
const String collectionStages = 'stages';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Variables de estado
  List<Map<String, dynamic>> _rankingData = [];
  bool _isLoading = true;
  String? _selectedStageId;
  String? _selectedStageName;
  List<Map<String, dynamic>> _stages = [];
  bool _showOnlyActive = true;
  
  // Parámetros de eliminación
  int _cutoffPosition = 10;
  final List<int> _cutoffOptions = [3, 5, 10, 15];
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    await _loadStages();
    await _calculateRanking();
  }
  
  Future<void> _loadStages() async {
    try {
      final snapshot = await _firestore
          .collection(collectionStages)
          .orderBy('order')
          .get();
      
      setState(() {
        _stages = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Sin nombre',
            'status': data['status'] ?? 'closed',
            'order': data['order'] ?? 0,
            'type': data['type'] ?? '',
          };
        }).toList();
        
        // Seleccionar la última etapa por defecto
        if (_stages.isNotEmpty) {
          _selectedStageId = _stages.last['id'];
          _selectedStageName = _stages.last['name'];
        }
      });
    } catch (e) {
      print('Error cargando etapas: $e');
    }
  }
  
  Future<void> _calculateRanking() async {
    setState(() => _isLoading = true);
    
    try {
      // Obtener todos los participantes
      final participantesSnapshot = await _firestore
          .collection(collectionParticipantes)
          .get();
      
      final List<Map<String, dynamic>> participantesConPromedio = [];
      
      for (var participanteDoc in participantesSnapshot.docs) {
        final participanteData = participanteDoc.data() as Map<String, dynamic>;
        final participanteId = participanteDoc.id;
        
        // Obtener calificaciones del participante
        Query query = _firestore
            .collection(collectionCalificaciones)
            .where('participanteId', isEqualTo: participanteId);
        
        // Si hay una etapa seleccionada, filtrar por ella
        if (_selectedStageId != null) {
          query = query.where('etapaId', isEqualTo: _selectedStageId);
        }
        
        final calificacionesSnapshot = await query.get();
        
        // Calcular estadísticas
        double total = 0;
        int count = 0;
        int calificacionesCount = calificacionesSnapshot.docs.length;
        List<Map<String, dynamic>> detallesCalificaciones = [];
        
        for (var calificacionDoc in calificacionesSnapshot.docs) {
          final calificacionData = calificacionDoc.data() as Map<String, dynamic>;
          final puntaje = calificacionData['puntaje'];
          final criterioId = calificacionData['criterioId'];
          final etapaId = calificacionData['etapaId'];
          final juezId = calificacionData['juezId'];
          final fecha = calificacionData['fecha'];
          
          if (puntaje != null) {
            double valorPuntaje = 0;
            if (puntaje is int) {
              valorPuntaje = puntaje.toDouble();
              total += valorPuntaje;
              count++;
            } else if (puntaje is double) {
              valorPuntaje = puntaje;
              total += valorPuntaje;
              count++;
            } else if (puntaje is num) {
              valorPuntaje = puntaje.toDouble();
              total += valorPuntaje;
              count++;
            }
            
            // Guardar detalle de calificación
            detallesCalificaciones.add({
              'puntaje': valorPuntaje,
              'criterioId': criterioId,
              'etapaId': etapaId,
              'juezId': juezId,
              'fecha': fecha,
            });
          }
        }
        
        final promedio = count > 0 ? total / count : 0.0;
        
        participantesConPromedio.add({
          'id': participanteId,
          'nombre': participanteData['nombre'] ?? 'Sin nombre',
          'idInterno': participanteData['idInterno'] ?? '',
          'activo': participanteData['activo'] ?? false,
          'promedio': promedio,
          'totalCalificaciones': calificacionesCount,
          'calificacionesValidas': count,
          'detallesCalificaciones': detallesCalificaciones,
        });
      }
      
      // Ordenar por promedio descendente
      participantesConPromedio.sort((a, b) => 
          (b['promedio'] as double).compareTo(a['promedio'] as double));
      
      // Asignar posición
      for (int i = 0; i < participantesConPromedio.length; i++) {
        participantesConPromedio[i]['posicion'] = i + 1;
      }
      
      setState(() {
        _rankingData = participantesConPromedio;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error calculando ranking: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Ranking General'),
        backgroundColor: Colors.amber.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateRanking,
            tooltip: 'Actualizar ranking',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportRanking,
            tooltip: 'Exportar ranking',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros y controles
          _buildControlsSection(),
          const SizedBox(height: 8),
          
          // Resumen del ranking
          _buildRankingSummary(),
          const SizedBox(height: 8),
          
          // Lista de participantes
          Expanded(
            child: _isLoading 
                ? _buildLoading()
                : _rankingData.isEmpty
                    ? _buildEmptyRanking()
                    : _buildRankingList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEliminationDialog,
        icon: const Icon(Icons.filter_alt),
        label: const Text('ELIMINAR PARTICIPANTES'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
  
  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedStageId,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por etapa',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('TODAS LAS ETAPAS'),
                    ),
                    ..._stages.map((stage) {
                      return DropdownMenuItem<String?>(
                        value: stage['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStageColor(stage['status']),
                              ),
                            ),
                            if (stage['type'] != null && stage['type'].isNotEmpty)
                              Text(
                                '(${stage['type']})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStageId = value;
                      if (value != null) {
                        final stage = _stages.firstWhere(
                          (s) => s['id'] == value,
                          orElse: () => {'name': 'Etapa'},
                        );
                        _selectedStageName = stage['name'];
                      } else {
                        _selectedStageName = null;
                      }
                    });
                    _calculateRanking();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    'Solo activos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Switch(
                    value: _showOnlyActive,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() => _showOnlyActive = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showStatistics,
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('ESTADÍSTICAS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showStageComparison,
                  icon: const Icon(Icons.compare),
                  label: const Text('COMPARAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRankingSummary() {
    final participantesActivos = _rankingData.where((p) => p['activo'] == true).length;
    final participantesTotales = _rankingData.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade100,
            Colors.orange.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade300.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedStageName != null
                      ? '🏆 RANKING: ${_selectedStageName!.toUpperCase()}'
                      : '🏆 RANKING GENERAL',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    children: [
                      const TextSpan(text: 'Total: '),
                      TextSpan(
                        text: '${_rankingData.length} participantes',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 107, 88, 64),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: participantesActivos > 0 ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: participantesActivos > 0 ? Colors.green.shade300 : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: participantesActivos > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$participantesActivos/$participantesTotales',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: participantesActivos > 0 ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'activos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Actualizado: ${DateFormat('HH:mm').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRankingList() {
    // Filtrar según opciones
    List<Map<String, dynamic>> filteredData = _rankingData;
    if (_showOnlyActive) {
      filteredData = filteredData.where((p) => p['activo'] == true).toList();
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final participant = filteredData[index];
        final position = participant['posicion'] ?? index + 1;
        final isActive = participant['activo'] == true;
        
        return _buildParticipantCard(participant, position, isActive);
      },
    );
  }
  
  Widget _buildParticipantCard(
    Map<String, dynamic> participant, 
    int position, 
    bool isActive,
  ) {
    final nombre = participant['nombre'] ?? 'Sin nombre';
    final idInterno = participant['idInterno'] ?? '';
    final promedio = participant['promedio'] ?? 0.0;
    final calificaciones = participant['totalCalificaciones'] ?? 0;
    final calificacionesValidas = participant['calificacionesValidas'] ?? 0;
    final detallesCalificaciones = participant['detallesCalificaciones'] as List<Map<String, dynamic>>? ?? [];
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isActive ? _getPositionColor(position) : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Posición con medalla
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getPositionColor(position),
                          _getPositionColor(position).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: position <= 3 ? [
                        BoxShadow(
                          color: _getPositionColor(position).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        position <= 3 ? _getPositionEmoji(position) : '$position',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Información del participante
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre destacado
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nombre,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? const Color.fromARGB(221, 255, 255, 255) : Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    'ELIMINADA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // ID del participante
                        Text(
                          'ID: $idInterno',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Estadísticas de calificaciones
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$calificaciones calificaciones',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (calificacionesValidas != calificaciones)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$calificacionesValidas válidas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        // Mostrar detalles de calificaciones si hay pocas
                        if (detallesCalificaciones.isNotEmpty && detallesCalificaciones.length <= 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Últimas calificaciones:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...detallesCalificaciones.take(3).map((calificacion) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          '• ${calificacion['puntaje']} pts',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${calificacion['criterioId'] ?? 'Sin criterio'})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Promedio destacado
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive
                                ? [_getPositionColor(position), _getPositionColor(position).withOpacity(0.8)]
                                : [Colors.grey.shade400, Colors.grey.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getPositionColor(position).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              promedio.toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/10',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PROMEDIO',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPositionColor(position),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Barra de progreso del promedio
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rendimiento:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${(promedio / 10 * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getPerformanceColor(promedio),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: promedio / 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getPerformanceColor(promedio),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.amber.shade700,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Calculando ranking...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Consultando calificaciones de Firebase',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyRanking() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'No hay datos de ranking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedStageId != null
                  ? 'No se encontraron calificaciones para esta etapa'
                  : 'No hay calificaciones registradas aún',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _calculateRanking,
              icon: const Icon(Icons.refresh),
              label: const Text('INTENTAR DE NUEVO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ============ MÉTODOS DE ELIMINACIÓN ============

  Future<void> _showEliminationDialog() async {
    // Filtrar solo participantes activos
    final activeParticipants = _rankingData.where((p) => p['activo'] == true).toList();
    
    if (activeParticipants.isEmpty) {
      _showErrorSnackbar('No hay participantes activos para eliminar');
      return;
    }
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 5),
                  const Text('ELIMINACIÓN POR RANKING'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información resumida
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '¡ATENCIÓN! Esta acción eliminará participantes',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Los participantes eliminados cambiarán su estado a "INACTIVO"',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Estadísticas actuales
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 105, 181, 235),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTADO ACTUAL',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow('Participantes totales:', '${_rankingData.length}'),
                          _buildStatRow('Participantes activos:', '${activeParticipants.length}'),
                          _buildStatRow('Participantes inactivos:', '${_rankingData.length - activeParticipants.length}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Configuración de eliminación
                    Text(
                      'CONFIGURACIÓN DE ELIMINACIÓN',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    Text(
                      'Selecciona el puesto de corte (los participantes con posición mayor a este número serán eliminados):',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Selector de posición de corte
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cutoffOptions.map((position) {
                        final participantsToEliminate = activeParticipants
                            .where((p) => p['posicion'] > position)
                            .length;
                        
                        return ChoiceChip(
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Top $position'),
                              const SizedBox(height: 2),
                              Text(
                                participantsToEliminate > 0 
                                    ? '$participantsToEliminate eliminarán'
                                    : 'Ninguno',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: participantsToEliminate > 0 
                                      ? Colors.red.shade700 
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          selected: _cutoffPosition == position,
                          selectedColor: const Color.fromARGB(255, 250, 133, 145),
                          backgroundColor: const Color.fromARGB(255, 99, 99, 99),
                          onSelected: (selected) {
                            setState(() {
                              _cutoffPosition = position;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Lista de participantes a eliminar
                    if (activeParticipants.where((p) => p['posicion'] > _cutoffPosition).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 81, 105),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_remove, size: 16, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'PARTICIPANTES A ELIMINAR (${activeParticipants.where((p) => p['posicion'] > _cutoffPosition).length})',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...activeParticipants
                                .where((p) => p['posicion'] > _cutoffPosition)
                                .take(5) // Mostrar solo los primeros 5
                                .map((participant) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Text(
                                      '#${participant['posicion']}',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        participant['nombre'],
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            
                            if (activeParticipants.where((p) => p['posicion'] > _cutoffPosition).length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '... y ${activeParticipants.where((p) => p['posicion'] > _cutoffPosition).length - 5} más',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _performElimination();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CONFIRMAR ELIMINACIÓN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performElimination() async {
    setState(() => _isLoading = true);
    
    try {
      // Filtrar participantes activos
      final activeParticipants = _rankingData.where((p) => p['activo'] == true).toList();
      
      if (activeParticipants.isEmpty) {
        throw Exception('No hay participantes activos para eliminar');
      }
      
      // Obtener los participantes que serán eliminados (posición mayor a cutoff)
      final participantsToEliminate = activeParticipants
          .where((participant) => participant['posicion'] > _cutoffPosition)
          .toList();
      
      if (participantsToEliminate.isEmpty) {
        _showSuccessSnackbar('No hay participantes para eliminar con el corte seleccionado');
        setState(() => _isLoading = false);
        return;
      }
      
      // Mostrar diálogo de confirmación final
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text('Confirmar Eliminación'),
            ],
          ),
          content: Text(
            '¿Estás seguro de eliminar a ${participantsToEliminate.length} participantes? '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ELIMINAR'),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Actualizar cada participante en Firebase
      int successCount = 0;
      int errorCount = 0;
      
      for (var participant in participantsToEliminate) {
        try {
          await _firestore
              .collection(collectionParticipantes)
              .doc(participant['id'])
              .update({
            'activo': false,
            'fechaEliminacion': FieldValue.serverTimestamp(),
            'posicionEliminacion': participant['posicion'],
            'etapaEliminacion': _selectedStageId,
          });
          
          successCount++;
          
          // Actualizar localmente el estado del participante
          final index = _rankingData.indexWhere((p) => p['id'] == participant['id']);
          if (index != -1) {
            _rankingData[index]['activo'] = false;
          }
          
        } catch (e) {
          print('Error eliminando participante ${participant['id']}: $e');
          errorCount++;
        }
      }
      
      // Recalcular el ranking con los nuevos estados
      await _calculateRanking();
      
      // Mostrar resultados
      _showEliminationResults(successCount, errorCount);
      
    } catch (e) {
      print('Error en eliminación: $e');
      _showErrorSnackbar('Error al realizar la eliminación: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showEliminationResults(int successCount, int errorCount) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('ELIMINACIÓN COMPLETADA'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '✅ Acción completada exitosamente',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  successCount.toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ELIMINADOS',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  (_rankingData.where((p) => p['activo'] == true).length).toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CONTINÚAN',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (errorCount > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '$errorCount participante(s) no pudieron ser eliminados',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'El ranking se ha actualizado automáticamente',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CONTINUAR'),
            ),
          ],
        );
      },
    );
  }

  // ============ MÉTODOS ADICIONALES ============

  Future<void> _toggleParticipantStatus(String participantId, bool currentStatus) async {
    try {
      await _firestore
          .collection(collectionParticipantes)
          .doc(participantId)
          .update({
        'activo': !currentStatus,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
      
      // Actualizar localmente
      final index = _rankingData.indexWhere((p) => p['id'] == participantId);
      if (index != -1) {
        setState(() {
          _rankingData[index]['activo'] = !currentStatus;
        });
      }
      
      _showSuccessSnackbar(
        !currentStatus 
          ? 'Participante activado exitosamente'
          : 'Participante desactivado exitosamente'
      );
      
      // Recalcular ranking si es necesario
      await _calculateRanking();
      
    } catch (e) {
      print('Error cambiando estado: $e');
      _showErrorSnackbar('Error al cambiar estado: $e');
    }
  }

  Future<void> _showParticipantDetails(String participantId) async {
    final participant = _rankingData.firstWhere(
      (p) => p['id'] == participantId,
      orElse: () => {},
    );
    
    if (participant.isEmpty) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de ${participant['nombre']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Nombre:', participant['nombre']),
              _buildStatRow('ID Interno:', participant['idInterno']),
              _buildStatRow('Estado:', participant['activo'] ? 'ACTIVO' : 'INACTIVO'),
              _buildStatRow('Posición:', '#${participant['posicion']}'),
              _buildStatRow('Promedio:', participant['promedio'].toStringAsFixed(2)),
              _buildStatRow('Calificaciones totales:', '${participant['totalCalificaciones']}'),
              _buildStatRow('Calificaciones válidas:', '${participant['calificacionesValidas']}'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (participant['detallesCalificaciones'] != null && 
                  (participant['detallesCalificaciones'] as List).isNotEmpty) ...[
                Text(
                  'Historial de calificaciones:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...(participant['detallesCalificaciones'] as List).map((cal) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '• ${cal['puntaje']} pts - ${cal['criterioId']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CERRAR'),
          ),
          ElevatedButton(
            onPressed: () => _toggleParticipantStatus(
              participantId, 
              participant['activo']
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: participant['activo'] ? Colors.red.shade700 : Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(
              participant['activo'] ? 'DESACTIVAR' : 'ACTIVAR'
            ),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    final activeParticipants = _rankingData.where((p) => p['activo'] == true).length;
    final totalParticipants = _rankingData.length;
    final bestScore = _rankingData.isNotEmpty ? 
        _rankingData.first['promedio'] as double : 0.0;
    final worstScore = _rankingData.isNotEmpty ? 
        _rankingData.last['promedio'] as double : 0.0;
    final avgScore = _rankingData.isNotEmpty ?
        _rankingData.map((p) => p['promedio'] as double).reduce((a, b) => a + b) / _rankingData.length : 0.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Estadísticas del Ranking'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Total participantes:', '$totalParticipants'),
                    _buildStatRow('Participantes activos:', '$activeParticipants'),
                    _buildStatRow('Participantes inactivos:', '${totalParticipants - activeParticipants}'),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildStatRow('Mejor puntaje:', bestScore.toStringAsFixed(2)),
                    _buildStatRow('Peor puntaje:', worstScore.toStringAsFixed(2)),
                    _buildStatRow('Puntaje promedio:', avgScore.toStringAsFixed(2)),
                    const SizedBox(height: 16),
                    _buildStatRow('Rango de puntajes:', '${worstScore.toStringAsFixed(2)} - ${bestScore.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  void _showStageComparison() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 Comparación por Etapas'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: _stages.isEmpty
              ? const Center(child: Text('No hay etapas disponibles'))
              : ListView.builder(
                  itemCount: _stages.length,
                  itemBuilder: (context, index) {
                    final stage = _stages[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStageColor(stage['status']),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(stage['name']),
                      subtitle: Text('Tipo: ${stage['type']}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStageColor(stage['status']).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stage['status'].toUpperCase(),
                          style: TextStyle(
                            color: _getStageColor(stage['status']),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedStageId = stage['id'];
                          _selectedStageName = stage['name'];
                        });
                        _calculateRanking();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportRanking() async {
    try {
      // Crear CSV simple
      String csvContent = 'Posición,Nombre,ID Interno,Promedio,Estado\n';
      
      for (var participant in _rankingData) {
        csvContent += '"${participant['posicion']}",'
                     '"${participant['nombre']}",'
                     '"${participant['idInterno']}",'
                     '"${participant['promedio']}",'
                     '"${participant['activo'] ? 'ACTIVO' : 'INACTIVO'}"\n';
      }
      
      // En una aplicación real, aquí guardarías o compartirías el archivo
      _showSuccessSnackbar('Ranking exportado exitosamente (${_rankingData.length} registros)');
      
    } catch (e) {
      print('Error exportando: $e');
      _showErrorSnackbar('Error al exportar: $e');
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============ MÉTODOS AUXILIARES ============

  String _getPositionEmoji(int position) {
    switch (position) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$position';
    }
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1: return Colors.amber.shade700;
      case 2: return Colors.grey.shade600;
      case 3: return Colors.orange.shade800;
      default: return Colors.blueGrey.shade600;
    }
  }

  Color _getStageColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'finished': return Colors.blue;
      case 'closed': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _getPerformanceColor(double promedio) {
    if (promedio >= 9) return Colors.green;
    if (promedio >= 7) return Colors.lightGreen;
    if (promedio >= 5) return Colors.orange;
    return Colors.red;
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}