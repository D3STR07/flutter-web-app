import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reina_nochebuena/ui/screens/admin/control_etapas_screen.dart';
import 'package:reina_nochebuena/ui/screens/admin/pdfs_screen.dart';
import 'package:reina_nochebuena/ui/screens/admin/ranking_participantes_screen.dart';

// Definiciones de colecciones
const String collectionParticipantes = 'participantes';
const String collectionJueces = 'jueces';
const String collectionCalificaciones = 'calificaciones';
const String collectionStages = 'stages';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👑 Panel de Administración'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
            tooltip: 'Notificaciones',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PARTE 1: Estado Actual del Concurso
              _buildStatusHeader(),
              const SizedBox(height: 20),

              // Resumen rápido con Calificaciones Pendientes
              _buildQuickSummary(),
              const SizedBox(height: 20),

              // ============ PARTE 2: MÉTRICAS EN TIEMPO REAL ============
              _buildSectionHeader(
                title: '📊 Métricas del Certamen',
                subtitle: 'Datos en tiempo real',
                icon: Icons.analytics,
              ),
              const SizedBox(height: 12),
              _buildMetricsGrid(),
              const SizedBox(height: 30),

              // ============ PARTE 3: MONITOREO AVANZADO DE JUECES ============
              _buildSectionHeader(
                title: '👨‍⚖️ Monitoreo de Jueces',
                subtitle: 'Estado actual de calificaciones',
                icon: Icons.gavel,
              ),
              const SizedBox(height: 12),
              _buildJudgeMonitoringSection(),
              const SizedBox(height: 30),

              // Estadísticas por Juez
              _buildSectionHeader(
                title: '📈 Estadísticas por Juez',
                subtitle: 'Desempeño individual',
                icon: Icons.bar_chart,
              ),
              const SizedBox(height: 12),
              _buildJudgeStatistics(),
              const SizedBox(height: 30),

              // ============ PARTE 4: TOP 3 PARTICIPANTES MEJORADO ============
              _buildSectionHeader(
                title: '🏆 Top 3 Participantes',
                subtitle: 'Mejores promedios generales',
                icon: Icons.emoji_events,
              ),
              const SizedBox(height: 12),
              _buildTopParticipants(),
              const SizedBox(height: 30),

              // Sección de Acciones Rápidas
              _buildSectionHeader(
                title: '⚡ Acciones Rápidas',
                subtitle: 'Acciones administrativas',
                icon: Icons.bolt,
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmergencyMenu(context),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.warning),
        tooltip: 'Acciones de Emergencia',
      ),
    );
  }

  // ============ PARTE 1: ESTADO ACTUAL DEL CONCURSO ============

  Widget _buildStatusHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionStages)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        String etapa = 'Cargando...';
        String subEtapa = '';
        Color color = Colors.grey;
        IconData icon = Icons.help;
        String maxScore = '10';
        String type = '';
        String status = '';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingStatusCard();
        }

        if (snapshot.hasError) {
          return _buildErrorStatusCard(snapshot.error.toString());
        }

        if (snapshot.hasData) {
          final stages = snapshot.data!.docs;
          
          if (stages.isEmpty) {
            etapa = 'Sin etapa activa';
            subEtapa = 'No hay etapa en progreso';
            color = Colors.grey.shade700;
            icon = Icons.pause_circle;
            status = 'inactive';
          } else {
            final stageData = stages.first.data() as Map<String, dynamic>;
            etapa = stageData['name']?.toString() ?? 'Etapa activa';
            subEtapa = stageData['subtitle']?.toString() ?? '';
            maxScore = (stageData['maxScore'] ?? 10).toString();
            type = stageData['type']?.toString() ?? '';
            status = stageData['status']?.toString() ?? 'closed';
            
            final config = _getStageConfig(type, etapa);
            color = config['color'] as Color;
            icon = config['icon'] as IconData;
          }
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ETAPA ACTUAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      etapa.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (subEtapa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          subEtapa,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (type.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Tipo: ${type.toUpperCase()} • Máx: $maxScore pts',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildStageStatusBadge(status),
            ],
          )
        );
      },
    );
  }

  Widget _buildLoadingStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ETAPA ACTUAL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Cargando...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CARGANDO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStatusCard(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.white, size: 36),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ERROR',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const Text(
                  'Error de conexión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  error.length > 50 ? '${error.substring(0, 50)}...' : error,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ERROR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageStatusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _buildStatusChip('EN PROGRESO', Colors.green);
      case 'finished':
        return _buildStatusChip('FINALIZADO', Colors.blue);
      case 'closed':
        return _buildStatusChip('CERRADO', Colors.red);
      case 'inactive':
        return _buildStatusChip('INACTIVO', Colors.grey);
      default:
        return _buildStatusChip('DESCONOCIDO', Colors.grey);
    }
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStageConfig(String type, String name) {
    final lowerType = type.toLowerCase();
    final lowerName = name.toLowerCase();
    
    if (lowerType.contains('pasarela')) {
      return {
        'color': Colors.purple.shade700,
        'icon': Icons.model_training,
      };
    } else if (lowerType.contains('entrevista')) {
      return {
        'color': Colors.blue.shade700,
        'icon': Icons.mic,
      };
    } else if (lowerType.contains('pregunta')) {
      return {
        'color': Colors.teal.shade700,
        'icon': Icons.question_answer,
      };
    }
    
    if (lowerName.contains('casual')) {
      return {
        'color': Colors.green.shade700,
        'icon': Icons.people,
      };
    } else if (lowerName.contains('final')) {
      return {
        'color': Colors.red.shade700,
        'icon': Icons.emoji_events,
      };
    } else if (lowerName.contains('noche')) {
      return {
        'color': Colors.indigo.shade700,
        'icon': Icons.nightlight_round,
      };
    } else if (lowerName.contains('opening')) {
      return {
        'color': Colors.orange.shade700,
        'icon': Icons.open_in_new,
      };
    } else if (lowerName.contains('rop casual')) {
      return {
        'color': Colors.lightBlue.shade700,
        'icon': Icons.checkroom,
      };
    } else {
      return {
        'color': Colors.grey.shade700,
        'icon': Icons.help,
      };
    }
  }

  // ============ PARTE 2: MÉTRICAS EN TIEMPO REAL ============

  Widget _buildQuickSummary() {
    return Column(
      children: [
        // Tarjeta de Jueces con Calificaciones Pendientes
        _buildPendingJudgesCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Avance del Día',
                value: '65%',
                icon: Icons.timeline,
                color: Colors.blue.shade600,
                progress: 0.65,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Tiempo Restante',
                value: '2h 30m',
                icon: Icons.access_time,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        // 1. Participantes Activos - CORREGIDO
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionParticipantes)
              .where('activo', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return _MetricCard(
              title: 'Participantes Activos',
              icon: Icons.person_add_alt_1,
              value: count,
              color: Colors.teal.shade700,
              suffix: '',
              tooltip: 'Total de participantes activos en el certamen',
              isDecimal: false,
            );
          },
        ),
        
        // 2. Calificaciones Últimas 48h
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionCalificaciones)
              .where('fecha', isGreaterThan: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(hours: 48)),
              ))
              .snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return _MetricCard(
              title: 'Calificaciones 48h',
              icon: Icons.star_rate,
              value: count,
              color: Colors.pink.shade700,
              suffix: '/48h',
              tooltip: 'Calificaciones registradas en las últimas 48 horas',
              isDecimal: false,
            );
          },
        ),
        
        // 3. Jueces Activos (con sesión activa)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionJueces)
              .where('rol', isEqualTo: 'juez')
              .where('activo', isEqualTo: true)
              .where('sesionActiva', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return _MetricCard(
              title: 'Jueces Activos',
              icon: Icons.gavel,
              value: count,
              color: Colors.indigo.shade700,
              suffix: '',
              tooltip: 'Jueces con sesión activa y listos para calificar',
              isDecimal: false,
            );
          },
        ),
        
        // 4. Promedio de Etapa Actual
        StreamBuilder<double>(
          stream: _getCurrentStageAverage(),
          builder: (context, snapshot) {
            double promedio = 0.0;
            if (snapshot.hasData) {
              promedio = snapshot.data!;
            }
            return _MetricCard(
              title: 'Promedio Etapa',
              icon: Icons.assessment,
              value: promedio,
              color: Colors.blueGrey.shade700,
              suffix: '/10',
              tooltip: 'Promedio general de la etapa actualmente activa',
              isDecimal: true,
            );
          },
        ),
      ],
    );
  }

  // Stream para calcular el promedio de la etapa actual - VERSIÓN SIMPLIFICADA
  Stream<double> _getCurrentStageAverage() {
    return FirebaseFirestore.instance
        .collection(collectionStages)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncExpand((stagesSnapshot) {
      if (stagesSnapshot.docs.isEmpty) {
        return Stream<double>.value(0.0);
      }
      
      final stageId = stagesSnapshot.docs.first.id;
      
      return FirebaseFirestore.instance
          .collection(collectionCalificaciones)
          .where('etapaId', isEqualTo: stageId)
          .snapshots()
          .map((calificacionesSnapshot) {
            if (calificacionesSnapshot.docs.isEmpty) return 0.0;
            
            double total = 0;
            int count = 0;
            
            for (var doc in calificacionesSnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final puntaje = data['puntaje'];
              if (puntaje != null) {
                if (puntaje is int) {
                  total += puntaje.toDouble();
                  count++;
                } else if (puntaje is double) {
                  total += puntaje;
                  count++;
                } else if (puntaje is num) {
                  total += puntaje.toDouble();
                  count++;
                }
              }
            }
            
            return count > 0 ? total / count : 0.0;
          });
    });
  }

  // ============ NUEVA FUNCIONALIDAD: Jueces con Calificaciones Pendientes ============

  Widget _buildPendingJudgesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .snapshots(),
      builder: (context, judgesSnapshot) {
        if (!judgesSnapshot.hasData) {
          return _buildLoadingPendingCard();
        }

        final jueces = judgesSnapshot.data!.docs;
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionStages)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, stagesSnapshot) {
            if (!stagesSnapshot.hasData || stagesSnapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('No hay etapa activa para verificar'),
                  ],
                ),
              );
            }

            final activeStageId = stagesSnapshot.data!.docs.first.id;

            return FutureBuilder<Map<String, int>>(
              future: _calculatePendingJudgments(activeStageId, jueces),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingPendingCard();
                }

                final pendingData = snapshot.data ?? {'total': 0, 'pendientes': 0};
                final totalJudges = pendingData['total'] ?? 0;
                final pendingJudges = pendingData['pendientes'] ?? 0;
                final completedJudges = totalJudges - pendingJudges;
                final completionRate = totalJudges > 0 ? completedJudges / totalJudges : .0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade50,
                        Colors.deepOrange.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📋 Calificaciones Pendientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pendingJudges > 0 
                                  ? Colors.orange.shade700 
                                  : Colors.green.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              pendingJudges > 0 ? 'PENDIENTE' : 'COMPLETADO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$completedJudges completaron',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      pendingJudges > 0 
                                          ? Icons.warning 
                                          : Icons.check,
                                      color: pendingJudges > 0 
                                          ? Colors.orange.shade700 
                                          : Colors.green.shade700,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$pendingJudges pendientes',
                                      style: TextStyle(
                                        color: pendingJudges > 0 
                                            ? Colors.orange.shade800 
                                            : Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${(completionRate * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                'Completado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completionRate,
                        backgroundColor: Colors.orange.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pendingJudges > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      if (pendingJudges > 0) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showPendingJudgesDetails(context, activeStageId),
                          icon: Icon(Icons.visibility, color: Colors.orange.shade700),
                          label: Text(
                            'Ver jueces pendientes',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _calculatePendingJudgments(
    String activeStageId, 
    List<QueryDocumentSnapshot> jueces,
  ) async {
    int totalJudges = 0;
    int pendingJudges = 0;

    try {
      // Obtener participantes activos una sola vez
      final participantesSnapshot = await FirebaseFirestore.instance
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();
      
      final participantesCount = participantesSnapshot.docs.length;

      for (var juezDoc in jueces) {
        final juezData = juezDoc.data() as Map<String, dynamic>;
        final juezId = juezDoc.id;
        
        if (juezData['activo'] == true && juezData['sesionActiva'] == true) {
          totalJudges++;
          
          final calificacionesSnapshot = await FirebaseFirestore.instance
              .collection(collectionCalificaciones)
              .where('etapaId', isEqualTo: activeStageId)
              .where('juezId', isEqualTo: juezId)
              .get();
          
          if (calificacionesSnapshot.docs.length < participantesCount) {
            pendingJudges++;
          }
        }
      }
    } catch (e) {
      print('Error calculando pendientes: $e');
    }

    return {
      'total': totalJudges,
      'pendientes': pendingJudges,
    };
  }

  Widget _buildLoadingPendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 12),
          Text('Calculando pendientes...'),
        ],
      ),
    );
  }

  void _showPendingJudgesDetails(BuildContext context, String stageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jueces con Calificaciones Pendientes'),
        content: FutureBuilder<Widget>(
          future: _buildPendingJudgesList(stageId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return snapshot.data ?? const Text('No hay datos');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildPendingJudgesList(String stageId) async {
    try {
      final juecesSnapshot = await FirebaseFirestore.instance
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .where('activo', isEqualTo: true)
          .where('sesionActiva', isEqualTo: true)
          .get();

      final participantesSnapshot = await FirebaseFirestore.instance
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();

      final participantesCount = participantesSnapshot.docs.length;
      final List<Widget> judgeTiles = [];

      for (var juezDoc in juecesSnapshot.docs) {
        final juezData = juezDoc.data() as Map<String, dynamic>;
        final juezId = juezDoc.id;
        final juezNombre = juezData['nombre'] ?? 'Sin nombre';
        final juezNum = juezData['numjuez'] ?? '';

        final calificacionesSnapshot = await FirebaseFirestore.instance
            .collection(collectionCalificaciones)
            .where('etapaId', isEqualTo: stageId)
            .where('juezId', isEqualTo: juezId)
            .get();

        final calificados = calificacionesSnapshot.docs.length;
        final pendientes = participantesCount - calificados;

        if (pendientes > 0) {
          final participantesCalificadosIds = calificacionesSnapshot.docs
              .map((doc) => doc['participanteId'] as String)
              .toSet();

          final participantesNoCalificados = participantesSnapshot.docs
              .where((doc) => !participantesCalificadosIds.contains(doc.id))
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['nombre'] ?? doc.id;
              })
              .toList();

          judgeTiles.add(ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(
                juezNum.isNotEmpty ? juezNum[0] : 'J',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
            title: Text(juezNombre),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Faltan $pendientes de $participantesCount'),
                if (participantesNoCalificados.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sin calificar: ${participantesNoCalificados.take(2).join(', ')}${participantesNoCalificados.length > 2 ? '...' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Chip(
              label: Text('$pendientes faltan'),
              backgroundColor: Colors.orange.shade100,
              labelStyle: TextStyle(color: Colors.orange.shade800),
            ),
          ));
        }
      }

      return SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: judgeTiles.isNotEmpty ? judgeTiles : [
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('¡Todos los jueces han completado!'),
              subtitle: Text('No hay calificaciones pendientes'),
            ),
          ],
        ),
      );
    } catch (e) {
      return Text('Error: $e');
    }
  }

  // ============ SECCIONES RESTANTES ============

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade700, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJudgeMonitoringSection() {
    return Column(
      children: [
        _buildJudgeStatusCard(),
        const SizedBox(height: 12),
        _buildDetailedJudgeList(),
      ],
    );
  }

  Widget _buildJudgeStatusCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .where('participanteActivo', isNull: false)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        List<Map<String, dynamic>> activeJudges = [];

        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
          activeJudges = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'nombre': data['nombre'],
              'participantes': data['participanteActivo'],
              'participanteNombre': data['participanteActivoNombre'],
              'numjuez': data['numjuez'],
              'id': doc.id,
            };
          }).toList();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade50,
                Colors.orange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count Jueces Calificando',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EN PROGRESO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeJudges.isNotEmpty)
                ...activeJudges.take(3).map((judge) => _buildJudgeTile(judge)).toList()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Ningún juez está calificando',
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              if (activeJudges.length > 3)
                TextButton.icon(
                  onPressed: () => _viewAllJudges(context, activeJudges),
                  icon: Icon(Icons.visibility, color: Colors.amber.shade700),
                  label: Text(
                    'Ver todos (${activeJudges.length})',
                    style: TextStyle(color: Colors.amber.shade700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJudgeTile(Map<String, dynamic> judge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.amber.shade200,
            child: Text(
              judge['numjuez'].toString().substring(0, 1),
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judge['nombre'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Calificando: ${judge['participanteNombre'] ?? judge['participantes']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(judge['numjuez'].toString()),
            backgroundColor: Colors.amber.shade100,
            labelStyle: TextStyle(color: Colors.amber.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedJudgeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .orderBy('activo', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final judges = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: judges.length,
          itemBuilder: (context, index) {
            final judge = judges[index];
            final data = judge.data() as Map<String, dynamic>;
            final isActive = data['activo'] == true;
            final hasActiveParticipant = data['participanteActivo'] != null;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(
                  isActive ? Icons.person : Icons.person_off,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
              title: Text(data['nombre'] ?? 'Sin nombre'),
              subtitle: Text(
                hasActiveParticipant
                    ? 'Calificando: ${data['participanteActivoNombre'] ?? data['participanteActivo']}'
                    : 'Disponible',
              ),
              trailing: Chip(
                label: Text(isActive ? 'Activo' : 'Inactivo'),
                backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: isActive ? Colors.green.shade800 : Colors.grey.shade800,
                ),
              ),
              onTap: () => _viewJudgeDetails(context, judge.id),
            );
          },
        );
      },
    );
  }

  // ============ PARTE 3: ESTADÍSTICAS POR JUEZ ============

  Widget _buildJudgeStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingCard('Cargando estadísticas...');
        }
        
        return FutureBuilder<List<Widget>>(
          future: _buildJudgeStatsCards(snapshot.data!.docs),
          builder: (context, statsSnapshot) {
            if (statsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard('Calculando estadísticas...');
            }
            
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: statsSnapshot.data ?? [],
            );
          },
        );
      },
    );
  }

  Future<List<Widget>> _buildJudgeStatsCards(List<QueryDocumentSnapshot> jueces) async {
    final List<Widget> cards = [];
    
    try {
      final activeStageId = await _getActiveStageId();
      
      if (activeStageId == null) {
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('No hay etapa activa'),
          )
        ];
      }
      
      // Obtener participantes activos
      final participantesSnapshot = await FirebaseFirestore.instance
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();
      
      final totalParticipantes = participantesSnapshot.docs.length;
      
      for (var juezDoc in jueces) {
        final juezData = juezDoc.data() as Map<String, dynamic>;
        final juezNombre = juezData['nombre'] ?? 'Sin nombre';
        final juezNum = juezData['numjuez'] ?? '';
        final isActive = juezData['activo'] == true;
        final hasActiveParticipant = juezData['participanteActivo'] != null;
        
        // Obtener calificaciones de este juez para la etapa activa
        final calificacionesSnapshot = await FirebaseFirestore.instance
            .collection(collectionCalificaciones)
            .where('etapaId', isEqualTo: activeStageId)
            .where('juezId', isEqualTo: juezDoc.id)
            .get();
        
        final calificadas = calificacionesSnapshot.docs.length;
        final porcentaje = totalParticipantes > 0 ? (calificadas / totalParticipantes * 100) : 0;
        
        // Calcular promedio del juez
        double promedio = 0;
        if (calificadas > 0) {
          double total = 0;
          for (var doc in calificacionesSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final puntaje = data['puntaje'];
            if (puntaje != null) {
              if (puntaje is int) {
                total += puntaje.toDouble();
              } else if (puntaje is double) {
                total += puntaje;
              } else if (puntaje is num) {
                total += puntaje.toDouble();
              }
            }
          }
          promedio = total / calificadas;
        }
        
        cards.add(
          Container(
            width: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isActive ? Colors.green.shade300 : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                      radius: 16,
                      child: Text(
                        juezNum.isNotEmpty ? juezNum[0] : 'J',
                        style: TextStyle(
                          color: isActive ? Colors.green.shade800 : Colors.grey.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        juezNombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isActive ? Colors.green.shade800 : Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calificadas',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '$calificadas/$totalParticipantes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Promedio',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          promedio.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: porcentaje / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    porcentaje >= 100 ? Colors.green : 
                    porcentaje >= 50 ? Colors.orange : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                Text(
                  '${porcentaje.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (hasActiveParticipant) ...[
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(
                      'CALIFICANDO',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    backgroundColor: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print('Error construyendo estadísticas: $e');
    }
    
    return cards;
  }

  // ============ PARTE 4: TOP 3 PARTICIPANTES MEJORADO ============

  Widget _buildTopParticipants() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _calculateTopParticipants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('Calculando top 3...');
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error: ${snapshot.error}');
        }

        final topParticipants = snapshot.data ?? [];

        if (topParticipants.isEmpty) {
          return _buildEmptyTopParticipants();
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade50,
                Colors.orange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.shade300.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.amber.shade200, width: 2),
          ),
          child: Column(
            children: [
              // Encabezado de podio
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'PODIO DE EXCELENCIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Contenido del top 3
              ...topParticipants.asMap().entries.map((entry) {
                final index = entry.key;
                final participant = entry.value;
                final nombre = participant['nombre'] ?? 'Sin nombre';
                final promedio = participant['promedio'] ?? 0.0;
                final idInterno = participant['idInterno'] ?? '';
                final totalCalificaciones = participant['totalCalificaciones'] ?? 0;
                final fechaUltimaCalificacion = participant['fechaUltimaCalificacion'];

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < topParticipants.length - 1
                          ? BorderSide(color: Colors.amber.shade100, width: 1)
                          : BorderSide.none,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getRankColor(index),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getRankColor(index).withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getRankText(index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getRankColor(index),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (idInterno.isNotEmpty)
                          Text(
                            'ID: $idInterno',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.shade700, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$totalCalificaciones calificaciones',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (fechaUltimaCalificacion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              'Última: ${_formatDate(fechaUltimaCalificacion)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getRankColor(index),
                                Color.lerp(_getRankColor(index), Colors.black, 0.1)!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _getRankColor(index).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
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
                              Text(
                                '/10',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PROMEDIO',
                          style: TextStyle(
                            fontSize: 9,
                            color: _getRankColor(index),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onTap: () => _viewParticipantDetails(context, participant['id']),
                  ),
                );
              }).toList(),
              
              // Pie de información
              if (topParticipants.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${topParticipants.length} participantes destacados',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _viewFullRanking(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Ver ranking completo →',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _calculateTopParticipants() async {
    try {
      // Obtener todos los participantes activos
      final participantesSnapshot = await FirebaseFirestore.instance
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();

      if (participantesSnapshot.docs.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> participantesConPromedio = [];

      // Calcular promedio para cada participante
      for (var participanteDoc in participantesSnapshot.docs) {
        final participanteData = participanteDoc.data() as Map<String, dynamic>;
        final participanteId = participanteDoc.id;

        // Obtener todas las calificaciones del participante
        final calificacionesSnapshot = await FirebaseFirestore.instance
            .collection(collectionCalificaciones)
            .where('participanteId', isEqualTo: participanteId)
            .get();

        double total = 0;
        int count = 0;
        Timestamp? fechaUltima = null;

        for (var calificacionDoc in calificacionesSnapshot.docs) {
          final calificacionData = calificacionDoc.data() as Map<String, dynamic>;
          final puntaje = calificacionData['puntaje'];
          final fecha = calificacionData['fecha'];

          if (puntaje != null) {
            if (puntaje is int) {
              total += puntaje.toDouble();
              count++;
            } else if (puntaje is double) {
              total += puntaje;
              count++;
            } else if (puntaje is num) {
              total += puntaje.toDouble();
              count++;
            }
          }

          // Actualizar fecha más reciente
          if (fecha is Timestamp) {
            if (fechaUltima == null || fecha.millisecondsSinceEpoch > fechaUltima.millisecondsSinceEpoch) {
              fechaUltima = fecha;
            }
          }
        }

        final promedio = count > 0 ? total / count : 0.0;

        participantesConPromedio.add({
          'id': participanteId,
          'nombre': participanteData['nombre'] ?? 'Sin nombre',
          'idInterno': participanteData['idInterno'] ?? '',
          'promedio': promedio,
          'totalCalificaciones': count,
          'fechaUltimaCalificacion': fechaUltima,
        });
      }

      // Ordenar por promedio descendente y tomar los 3 mejores
      participantesConPromedio.sort((a, b) => (b['promedio'] as double).compareTo(a['promedio'] as double));

      return participantesConPromedio.take(3).toList();
    } catch (e) {
      print('Error calculando top participantes: $e');
      return [];
    }
  }

  String _getRankText(int index) {
    switch (index) {
      case 0: return '🥇';
      case 1: return '🥈';
      case 2: return '🥉';
      default: return '${index + 1}';
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyTopParticipants() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No hay participantes calificados aún',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esperando que los jueces asignen calificaciones',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber.shade700;
      case 1: return Colors.grey.shade600;
      case 2: return Colors.orange.shade800;
      default: return Colors.blueGrey.shade600;
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'label': 'Ver Ranking',
        'icon': Icons.leaderboard,
        'color': Colors.green.shade700,
        'action': () => _navigateToRanking(context),
      },
      {
        'label': 'Control Etapas',
        'icon': Icons.timeline,
        'color': Colors.purple.shade700,
        'action': () => _navigateToStageControl(context),
      },
      {
        'label': 'Gestionar Jueces',
        'icon': Icons.supervised_user_circle,
        'color': Colors.blue.shade700,
        'action': () => _navigateToJudgeManagement(context),
      },
      {
        'label': 'Añadir Participante',
        'icon': Icons.person_add,
        'color': Colors.pink.shade700,
        'action': () => _addParticipant(context),
      },
      {
        'label': 'Reportes',
        'icon': Icons.summarize,
        'color': Colors.orange.shade700,
        'action': () => _generateReports(context),
      },
      {
        'label': 'Configuración',
        'icon': Icons.settings,
        'color': Colors.grey.shade700,
        'action': () => _openSettings(context),
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((action) {
        return _ActionButton(
          label: action['label'] as String,
          icon: action['icon'] as IconData,
          onPressed: action['action'] as VoidCallback,
          color: action['color'] as Color,
        );
      }).toList(),
    );
  }

  // ============ MÉTODOS AUXILIARES ============

  Future<double> _calculateParticipantAverageSimple(String participantId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionCalificaciones)
          .where('participanteId', isEqualTo: participantId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double total = 0;
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final puntaje = data['puntaje'];
        if (puntaje != null) {
          if (puntaje is int) {
            total += puntaje.toDouble();
            count++;
          } else if (puntaje is double) {
            total += puntaje;
            count++;
          } else if (puntaje is num) {
            total += puntaje.toDouble();
            count++;
          }
        }
      }

      return count > 0 ? total / count : 0.0;
    } catch (e) {
      print('Error calculando promedio: $e');
      return 0.0;
    }
  }

  Future<String?> _getActiveStageId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionStages)
          .where('status', isEqualTo: 'active')
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error obteniendo etapa activa: $e');
      return null;
    }
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
    );
  }

  // ============ MÉTODOS DE ACCIÓN ============

  void _showNotifications() {
    print('Mostrar notificaciones');
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚨 Acciones de Emergencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _EmergencyButton(
              label: 'Pausar Certamen',
              icon: Icons.pause_circle,
              color: Colors.orange,
              onPressed: () => _pauseCompetition(context),
            ),
            _EmergencyButton(
              label: 'Reiniciar Etapa',
              icon: Icons.replay,
              color: Colors.blue,
              onPressed: () => _restartStage(context),
            ),
            _EmergencyButton(
              label: 'Bloquear Jueces',
              icon: Icons.block,
              color: Colors.red,
              onPressed: () => _blockJudges(context),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewAllJudges(BuildContext context, List<Map<String, dynamic>> judges) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todos los Jueces Activos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: judges.map((judge) => ListTile(
              title: Text(judge['nombre']),
              subtitle: Text('Calificando: ${judge['participanteNombre']}'),
              trailing: Text(judge['numjuez']),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _viewJudgeDetails(BuildContext context, String judgeId) {
    print('Ver detalles del juez: $judgeId');
  }

  void _viewParticipantDetails(BuildContext context, String participantId) {
    print('Ver detalles del participante: $participantId');
  }

  void _viewFullRanking(BuildContext context) {
    print('Ver ranking completo');
  }

  void _navigateToRanking(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RankingScreen(),
        ),
      );
  }

  void _navigateToStageControl(BuildContext context) {
     Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StageControlScreen(),
        ),
      );
  }

  void _navigateToJudgeManagement(BuildContext context) {
    print('Navegar a gestión de jueces');
  }

  void _addParticipant(BuildContext context) {
    print('Añadir participante');
  }

  void _generateReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PdfGenerationScreen(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    print('Abrir configuración');
  }

  void _pauseCompetition(BuildContext context) {
    print('Pausar competencia');
  }

  void _restartStage(BuildContext context) {
    print('Reiniciar etapa');
  }

  void _blockJudges(BuildContext context) {
    print('Bloquear jueces');
  }
}

// ============ CLASES AUXILIARES ============

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress!,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final dynamic value;
  final Color color;
  final String suffix;
  final bool isDecimal;
  final String? tooltip;

  const _MetricCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.color,
    this.suffix = '',
    this.isDecimal = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? title,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              Color.lerp(color, Colors.black, 0.1)!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -10,
              right: -10,
              child: Icon(
                icon,
                size: 60,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isDecimal ? (value as double).toStringAsFixed(1) : value.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        if (suffix.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 2.0),
                            child: Text(
                              suffix,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 22,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: color.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _EmergencyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}