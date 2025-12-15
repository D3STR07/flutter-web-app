import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// Definiciones de colecciones
const String collectionParticipantes = 'participantes';
const String collectionJueces = 'jueces';
const String collectionCalificaciones = 'calificaciones';
const String collectionStages = 'stages';
const String subcollectionQuestions = 'questions';

class PdfGenerationScreen extends StatefulWidget {
  const PdfGenerationScreen({super.key});

  @override
  State<PdfGenerationScreen> createState() => _PdfGenerationScreenState();
}

class _PdfGenerationScreenState extends State<PdfGenerationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isGenerating = false;
  double _progress = 0.0;
  String _currentTask = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 Generación de Reportes'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressIndicator(),
            const SizedBox(height: 24),
            
            // Encabezado
            const Text(
              '📊 Selecciona el tipo de reporte:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Grid de opciones de PDF
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildPdfOptionCard(
                    title: '📋 Calificaciones Generales',
                    subtitle: 'Reporte oficial completo',
                    icon: Icons.assignment,
                    color: Colors.blue.shade700,
                    onTap: () => _generateGeneralReport(),
                  ),
                  _buildPdfOptionCard(
                    title: '👤 Por Participante',
                    subtitle: 'Reporte individual detallado',
                    icon: Icons.person,
                    color: Colors.green.shade700,
                    onTap: () => _showParticipantSelection(),
                  ),
                  _buildPdfOptionCard(
                    title: '🏆 Ranking Final',
                    subtitle: 'Resultados finales',
                    icon: Icons.emoji_events,
                    color: Colors.orange.shade700,
                    onTap: () => _generateRankingReport(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (!_isGenerating) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTask,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}% completado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ MÉTODOS PRINCIPALES ============

  Future<void> _generateGeneralReport() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _currentTask = 'Recopilando datos generales...';
    });

    try {
      // 1. Obtener todos los datos necesarios
      _updateProgress('Obteniendo participantes...', 0.1);
      final participantesSnapshot = await _firestore
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();

      _updateProgress('Obteniendo etapas...', 0.2);
      final stagesSnapshot = await _firestore
          .collection(collectionStages)
          .orderBy('order')
          .get();

      // Obtener preguntas/criterios de cada etapa
      final Map<String, List<Map<String, dynamic>>> preguntasPorEtapa = {};
      for (var stage in stagesSnapshot.docs) {
        final stageId = stage.id;
        final questionsSnapshot = await _firestore
            .collection(collectionStages)
            .doc(stageId)
            .collection(subcollectionQuestions)
            .get();
        
        preguntasPorEtapa[stageId] = questionsSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return {
                'id': doc.id,
                'nombre': data?['nombre'] ?? doc.id,
                'descripcion': data?['descripcion'] ?? '',
              };
            })
            .toList();
      }

      _updateProgress('Obteniendo jueces activos...', 0.3);
      final juecesSnapshot = await _firestore
          .collection(collectionJueces)
          .where('rol', isEqualTo: 'juez')
          .where('activo', isEqualTo: true)
          .get();

      _updateProgress('Obteniendo calificaciones...', 0.4);
      final calificacionesSnapshot = await _firestore
          .collection(collectionCalificaciones)
          .get();

      // 2. Calcular promedios
      _updateProgress('Calculando promedios...', 0.6);
      final participantesConPromedio = await _calculateAllAverages();

      // 3. Generar PDF
      _updateProgress('Generando documento PDF...', 0.8);
      final pdf = pw.Document();

      // Página 1: Portada
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildCoverPage(
              title: 'REPORTE GENERAL DE CALIFICACIONES',
              subtitle: 'Certamen de Nochebuena',
              fecha: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
            );
          },
        ),
      );

      // Página 2: Resumen ejecutivo
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildExecutiveSummary(
              participantes: participantesSnapshot.docs.length,
              etapas: stagesSnapshot.docs.length,
              jueces: juecesSnapshot.docs.length,
              calificaciones: calificacionesSnapshot.docs.length,
            );
          },
        ),
      );

      // Página 3: Lista de participantes activos
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildParticipantsList(
              participantes: participantesSnapshot.docs,
            );
          },
        ),
      );

      // Página 4: Lista de jueces activos
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildJudgesList(
              jueces: juecesSnapshot.docs,
            );
          },
        ),
      );

      // Página 5: Lista de etapas con preguntas
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildStagesList(
              stages: stagesSnapshot.docs,
              preguntasPorEtapa: preguntasPorEtapa,
            );
          },
        ),
      );

      // Páginas 6+: Ranking por etapa
      for (var stage in stagesSnapshot.docs) {
        final stageId = stage.id;
        final stageData = stage.data() as Map<String, dynamic>?;
        
        // Calcular ranking para esta etapa
        final rankingEtapa = await _calculateStageRanking(stageId);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildStageRankingPage(
                stageName: stageData?['name'] ?? 'Etapa',
                stageType: stageData?['type'] ?? '',
                ranking: rankingEtapa,
              );
            },
          ),
        );
      }

      // Última página: Ranking general final
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildFinalRankingPage(
              participantes: participantesConPromedio,
            );
          },
        ),
      );

      // Página final: Detalle por criterio
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildCriteriaDetailPage(
              preguntasPorEtapa: preguntasPorEtapa,
              stages: stagesSnapshot.docs,
            );
          },
        ),
      );

      // Página de firmas
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildSignaturesPage();
          },
        ),
      );

      // 4. Guardar y mostrar PDF
      _updateProgress('Guardando documento...', 0.95);
      await _saveAndOpenPdf(
        pdf: pdf,
        fileName: 'Reporte_General_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );

      _updateProgress('Completado', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      
      _showSuccessDialog('✅ Reporte general generado exitosamente');

    } catch (e) {
      _showErrorDialog('❌ Error al generar reporte: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateParticipantReport(String participantId) async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _currentTask = 'Generando reporte individual...';
    });

    try {
      // Obtener datos del participante
      final participantDoc = await _firestore
          .collection(collectionParticipantes)
          .doc(participantId)
          .get();
      
      if (!participantDoc.exists) {
        throw Exception('Participante no encontrado');
      }

      final participantData = participantDoc.data() as Map<String, dynamic>?;
      final participantName = participantData?['nombre'] ?? 'Sin nombre';
      final participantIdInterno = participantData?['idInterno'] ?? '';

      // Obtener todas las calificaciones del participante
      final calificacionesSnapshot = await _firestore
          .collection(collectionCalificaciones)
          .where('participanteId', isEqualTo: participantId)
          .get();

      // Obtener etapas
      final stagesSnapshot = await _firestore
          .collection(collectionStages)
          .orderBy('order')
          .get();

      // Obtener preguntas de cada etapa
      final Map<String, List<Map<String, dynamic>>> preguntasPorEtapa = {};
      for (var stage in stagesSnapshot.docs) {
        final stageId = stage.id;
        final questionsSnapshot = await _firestore
            .collection(collectionStages)
            .doc(stageId)
            .collection(subcollectionQuestions)
            .get();
        
        preguntasPorEtapa[stageId] = questionsSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return {
                'id': doc.id,
                'nombre': data?['nombre'] ?? doc.id,
                'descripcion': data?['descripcion'] ?? '',
              };
            })
            .toList();
      }

      // Calcular estadísticas por etapa
      final estadisticasPorEtapa = await _calculateParticipantStats(
        participantId,
        calificacionesSnapshot.docs,
        stagesSnapshot.docs,
        preguntasPorEtapa,
      );

      // Generar PDF
      final pdf = pw.Document();

      // Portada
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildParticipantCoverPage(
              participantName: participantName,
              participantId: participantIdInterno,
              fecha: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
            );
          },
        ),
      );

      // Resumen general
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildParticipantSummaryPage(
              participantName: participantName,
              totalCalificaciones: calificacionesSnapshot.docs.length,
              estadisticasPorEtapa: estadisticasPorEtapa,
            );
          },
        ),
      );

      // Detalle por etapa
      for (var etapa in estadisticasPorEtapa) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildParticipantStageDetailPage(
                etapa: etapa,
                calificaciones: calificacionesSnapshot.docs
                    .where((c) => c.get('etapaId') == etapa['id'])
                    .toList(),
                preguntas: preguntasPorEtapa[etapa['id']] ?? [],
              );
            },
          ),
        );
      }

      // Página de comentarios (si hay)
      final comentarios = calificacionesSnapshot.docs
          .where((doc) {
            final comment = doc.get('comentario');
            return comment != null && comment.toString().isNotEmpty;
          })
          .toList();
      
      if (comentarios.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildCommentsPage(
                participantName: participantName,
                comentarios: comentarios,
              );
            },
          ),
        );
      }

      // Guardar PDF
      await _saveAndOpenPdf(
        pdf: pdf,
        fileName: 'Reporte_${participantName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      _showSuccessDialog('✅ Reporte individual generado exitosamente');

    } catch (e) {
      _showErrorDialog('❌ Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateRankingReport() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _currentTask = 'Generando ranking final...';
    });

    try {
      // Obtener ranking general
      final participantesConPromedio = await _calculateAllAverages();
      
      // Obtener etapas
      final stagesSnapshot = await _firestore
          .collection(collectionStages)
          .orderBy('order')
          .get();

      // Generar PDF
      final pdf = pw.Document();

      // Portada
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildRankingCoverPage(
              fecha: DateFormat('dd/MM/yyyy').format(DateTime.now()),
              totalParticipantes: participantesConPromedio.length,
            );
          },
        ),
      );

      // Top 10
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildTop10Page(
              participantes: participantesConPromedio.take(10).toList(),
            );
          },
        ),
      );

      // Ranking completo
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildFullRankingPage(
              participantes: participantesConPromedio,
            );
          },
        ),
      );

      // Rankings por etapa
      for (var stage in stagesSnapshot.docs) {
        final stageId = stage.id;
        final stageData = stage.data() as Map<String, dynamic>?;
        final ranking = await _calculateStageRanking(stageId);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildStageRankingForPress(
                stageName: stageData?['name'] ?? 'Etapa',
                ranking: ranking,
              );
            },
          ),
        );
      }

      // Guardar
      await _saveAndOpenPdf(
        pdf: pdf,
        fileName: 'Ranking_Final_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      _showSuccessDialog('✅ Ranking final generado exitosamente');

    } catch (e) {
      _showErrorDialog('❌ Error al generar ranking: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ MÉTODOS DE SELECCIÓN ============

  void _showParticipantSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Participante'),
        content: FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection(collectionParticipantes)
              .where('activo', isEqualTo: true)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final participantes = snapshot.data?.docs ?? [];
            
            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: participantes.length,
                itemBuilder: (context, index) {
                  final doc = participantes[index];
                  final data = doc.data() as Map<String, dynamic>?;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      data?['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('ID: ${data?['idInterno'] ?? ''}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      _generateParticipantReport(doc.id);
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // ============ MÉTODOS AUXILIARES ============

  void _updateProgress(String task, double progress) {
    setState(() {
      _currentTask = task;
      _progress = progress;
    });
  }

  Future<void> _saveAndOpenPdf({required pw.Document pdf, required String fileName}) async {
    final bytes = await pdf.save();
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Éxito'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _calculateAllAverages() async {
    final participantesSnapshot = await _firestore
        .collection(collectionParticipantes)
        .where('activo', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> resultados = [];

    for (var doc in participantesSnapshot.docs) {
      final participanteId = doc.id;
      final participanteData = doc.data() as Map<String, dynamic>?;

      final calificacionesSnapshot = await _firestore
          .collection(collectionCalificaciones)
          .where('participanteId', isEqualTo: participanteId)
          .get();

      double total = 0;
      int count = 0;

      for (var calificacion in calificacionesSnapshot.docs) {
        final puntaje = calificacion.get('puntaje');
        
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

      final promedio = count > 0 ? total / count : 0.0;

      resultados.add({
        'id': participanteId,
        'nombre': participanteData?['nombre'],
        'idInterno': participanteData?['idInterno'],
        'promedio': promedio,
        'totalCalificaciones': count,
      });
    }

    resultados.sort((a, b) => (b['promedio'] as double).compareTo(a['promedio'] as double));
    
    for (int i = 0; i < resultados.length; i++) {
      resultados[i]['posicion'] = i + 1;
    }

    return resultados;
  }

  Future<List<Map<String, dynamic>>> _calculateStageRanking(String stageId) async {
    final participantesSnapshot = await _firestore
        .collection(collectionParticipantes)
        .where('activo', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> resultados = [];

    for (var doc in participantesSnapshot.docs) {
      final participanteId = doc.id;
      final participanteData = doc.data() as Map<String, dynamic>?;

      final calificacionesSnapshot = await _firestore
          .collection(collectionCalificaciones)
          .where('participanteId', isEqualTo: participanteId)
          .where('etapaId', isEqualTo: stageId)
          .get();

      double total = 0;
      int count = 0;

      for (var calificacion in calificacionesSnapshot.docs) {
        final puntaje = calificacion.get('puntaje');
        
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

      final promedio = count > 0 ? total / count : 0.0;

      resultados.add({
        'id': participanteId,
        'nombre': participanteData?['nombre'],
        'idInterno': participanteData?['idInterno'],
        'promedio': promedio,
        'calificaciones': count,
      });
    }

    resultados.sort((a, b) => (b['promedio'] as double).compareTo(a['promedio'] as double));
    
    for (int i = 0; i < resultados.length; i++) {
      resultados[i]['posicion'] = i + 1;
    }
    
    return resultados;
  }

  Future<List<Map<String, dynamic>>> _calculateParticipantStats(
    String participantId,
    List<QueryDocumentSnapshot> calificaciones,
    List<QueryDocumentSnapshot> stages,
    Map<String, List<Map<String, dynamic>>> preguntasPorEtapa,
  ) async {
    final List<Map<String, dynamic>> estadisticas = [];

    for (var stage in stages) {
      final stageId = stage.id;
      final stageData = stage.data() as Map<String, dynamic>?;

      final calificacionesEtapa = calificaciones
          .where((c) => c.get('etapaId') == stageId)
          .toList();

      double total = 0;
      int count = 0;
      List<Map<String, dynamic>> detalles = [];

      // Calcular por criterio/pregunta
      final criteriosStats = <String, List<double>>{};
      final preguntas = preguntasPorEtapa[stageId] ?? [];
      
      for (var pregunta in preguntas) {
        criteriosStats[pregunta['id']] = [];
      }

      for (var calificacion in calificacionesEtapa) {
        final puntaje = calificacion.get('puntaje');
        final criterioId = calificacion.get('criterioId');
        
        if (puntaje != null && criterioId != null) {
          double valor = 0;
          if (puntaje is int) {
            valor = puntaje.toDouble();
          } else if (puntaje is double) {
            valor = puntaje;
          } else if (puntaje is num) {
            valor = puntaje.toDouble();
          }
          
          total += valor;
          count++;
          
          // Agregar a estadísticas del criterio
          if (criteriosStats.containsKey(criterioId)) {
            criteriosStats[criterioId]!.add(valor);
          }
          
          detalles.add({
            'puntaje': valor,
            'criterioId': criterioId,
            'juezId': calificacion.get('juezId'),
            'fecha': calificacion.get('fecha'),
            'comentario': calificacion.get('comentario'),
          });
        }
      }

      final promedio = count > 0 ? total / count : 0.0;

      // Calcular promedios por criterio
      final promediosPorCriterio = <String, double>{};
      for (var entry in criteriosStats.entries) {
        final criterioId = entry.key;
        final calificaciones = entry.value;
        if (calificaciones.isNotEmpty) {
          promediosPorCriterio[criterioId] = calificaciones.reduce((a, b) => a + b) / calificaciones.length;
        }
      }

      estadisticas.add({
        'id': stageId,
        'nombre': stageData?['name'],
        'tipo': stageData?['type'],
        'maxScore': stageData?['maxScore'] ?? 10,
        'promedio': promedio,
        'totalCalificaciones': count,
        'detalles': detalles,
        'promediosPorCriterio': promediosPorCriterio,
      });
    }

    return estadisticas;
  }

  // ============ MÉTODOS DE CONSTRUCCIÓN DE PDF ============

  pw.Widget _buildCoverPage({
    required String title,
    required String subtitle,
    required String fecha,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topCenter,
          end: pw.Alignment.bottomCenter,
          colors: [PdfColors.blue, PdfColors.blue800],
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'CERTAMEN DE NOCHEBUENA',
            style: pw.TextStyle(
              fontSize: 24,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 32,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.white,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x1AFFFFFF),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Documento Oficial',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Generado el: $fecha',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColor.fromInt(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 60),
          pw.Text(
            'Sello Oficial del Certamen',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColor.fromInt(0x99FFFFFF),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildExecutiveSummary({
    required int participantes,
    required int etapas,
    required int jueces,
    required int calificaciones,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'RESUMEN EJECUTIVO',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Este documento presenta los resultados oficiales del Certamen de Nochebuena '
          'contabilizando todas las evaluaciones realizadas por el panel de jueces.',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 30),
        pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildStatBox('Participantes', participantes.toString(), PdfColors.blue),
            _buildStatBox('Etapas', etapas.toString(), PdfColors.green),
            _buildStatBox('Jueces Activos', jueces.toString(), PdfColors.purple),
            _buildStatBox('Calificaciones', calificaciones.toString(), PdfColors.orange),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Text(
          'Metodología de Evaluación:',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Bullet(
          text: 'Sistema de puntuación del 1 al 10 puntos por cada criterio',
          style: pw.TextStyle(fontSize: 11),
        ),
        pw.Bullet(
          text: 'Evaluación realizada por 12 jueces especializados',
          style: pw.TextStyle(fontSize: 11),
        ),
        pw.Bullet(
          text: 'Promedio calculado sobre todas las calificaciones válidas',
          style: pw.TextStyle(fontSize: 11),
        ),
        pw.Bullet(
          text: 'Documento con validez oficial ante autoridades municipales',
          style: pw.TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  pw.Container _buildStatBox(String title, String value, PdfColor color) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildParticipantsList({
    required List<QueryDocumentSnapshot> participantes,
  }) {
    final data = [
      ['#', 'ID', 'NOMBRE', 'ESTADO'],
      for (var i = 0; i < participantes.length; i++)
        [
          '${i + 1}',
          participantes[i].get('idInterno') ?? '',
          participantes[i].get('nombre') ?? 'Sin nombre',
          participantes[i].get('activo') == true ? 'ACTIVO' : 'INACTIVO',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'PARTICIPANTES REGISTRADOS',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Total: ${participantes.length} participantes',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blue700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
      ],
    );
  }

  pw.Widget _buildJudgesList({
    required List<QueryDocumentSnapshot> jueces,
  }) {
    final data = [
      ['#', 'ID JUEZ', 'NOMBRE', 'ROL', 'ESTADO'],
      for (var i = 0; i < jueces.length; i++)
        [
          '${i + 1}',
          jueces[i].get('idInterno') ?? '',
          jueces[i].get('nombre') ?? 'Sin nombre',
          (jueces[i].get('rol')?.toString().toUpperCase() ?? 'JUEZ'),
          jueces[i].get('activo') == true ? 'ACTIVO' : 'INACTIVO',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'PANEL DE JUECES',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Lista oficial de jueces que participaron en la evaluación:',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.green700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Total jueces activos: ${jueces.length}',
          style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  pw.Widget _buildStagesList({
    required List<QueryDocumentSnapshot> stages,
    required Map<String, List<Map<String, dynamic>>> preguntasPorEtapa,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'ETAPAS DEL CERTAMEN',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Descripción de cada una de las etapas evaluadas:',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 15),
        for (var stage in stages)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      stage.get('name') ?? 'Sin nombre',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: _getStageColor(stage.get('color') ?? 'blue'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        (stage.get('type')?.toString().toUpperCase() ?? ''),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Subtítulo: ${stage.get('subtitle') ?? 'No disponible'}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text(
                      'Puntaje máximo: ${stage.get('maxScore') ?? 10} puntos',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      'Orden: ${stage.get('order') ?? 0}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'Estado: ${stage.get('status') ?? 'unknown'}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                if (preguntasPorEtapa[stage.id]?.isNotEmpty ?? false)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Criterios de evaluación:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      for (var pregunta in preguntasPorEtapa[stage.id]!)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
                          child: pw.Text(
                            '• ${pregunta['nombre']}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  PdfColor _getStageColor(String color) {
    switch (color.toLowerCase()) {
      case 'red':
        return PdfColors.red;
      case 'green':
        return PdfColors.green;
      case 'blue':
        return PdfColors.blue;
      case 'purple':
        return PdfColors.purple;
      case 'orange':
        return PdfColors.orange;
      default:
        return PdfColors.blue;
    }
  }

  pw.Widget _buildStageRankingPage({
    required String stageName,
    required String stageType,
    required List<Map<String, dynamic>> ranking,
  }) {
    final data = [
      ['POSICIÓN', 'PARTICIPANTE', 'ID', 'PROMEDIO', 'CALIFICACIONES'],
      for (var i = 0; i < ranking.length; i++)
        [
          '${i + 1}',
          ranking[i]['nombre'] ?? '',
          ranking[i]['idInterno'] ?? '',
          '${ranking[i]['promedio']?.toStringAsFixed(2) ?? '0.00'}',
          '${ranking[i]['calificaciones'] ?? 0}',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'RANKING - $stageName',
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Tipo: ${stageType.toUpperCase()}',
          style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.purple700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
      ],
    );
  }

  pw.Widget _buildFinalRankingPage({
    required List<Map<String, dynamic>> participantes,
  }) {
    final data = [
      ['POSICIÓN', 'PARTICIPANTE', 'ID', 'PROMEDIO FINAL', 'CALIFICACIONES'],
      for (var i = 0; i < participantes.length; i++)
        [
          '${i + 1}',
          participantes[i]['nombre'] ?? '',
          participantes[i]['idInterno'] ?? '',
          '${participantes[i]['promedio']?.toStringAsFixed(2) ?? '0.00'}',
          '${participantes[i]['totalCalificaciones'] ?? 0}',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'RANKING FINAL GENERAL',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Resultados consolidados de todas las etapas del certamen:',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.orange700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 30),
        // Top 3 destacado
        if (participantes.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColors.amber200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TOP 3 DEL CERTAMEN',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber800,
                  ),
                ),
                pw.SizedBox(height: 15),
                for (var i = 0; i < 3 && i < participantes.length; i++)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: i == 0
                          ? PdfColors.amber100
                          : i == 1
                              ? PdfColors.grey100
                              : PdfColors.orange100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          i == 0 ? '🥇' : i == 1 ? '🥈' : '🥉',
                          style: pw.TextStyle(fontSize: 20),
                        ),
                        pw.SizedBox(width: 15),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                participantes[i]['nombre'] ?? '',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Text(
                                'ID: ${participantes[i]['idInterno'] ?? ''}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '${participantes[i]['promedio']?.toStringAsFixed(2) ?? '0.00'} pts',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: i == 0
                                ? PdfColors.amber800
                                : i == 1
                                    ? PdfColors.grey800
                                    : PdfColors.orange800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildCriteriaDetailPage({
    required Map<String, List<Map<String, dynamic>>> preguntasPorEtapa,
    required List<QueryDocumentSnapshot> stages,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'DETALLE DE CRITERIOS DE EVALUACIÓN',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Descripción detallada de los criterios evaluados en cada etapa:',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        
        for (var stage in stages)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  stage.get('name') ?? 'Etapa',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 10),
                
                if (preguntasPorEtapa[stage.id]?.isNotEmpty ?? false)
                  pw.TableHelper.fromTextArray(
                    data: [
                      ['#', 'CRITERIO', 'DESCRIPCIÓN'],
                      for (var i = 0; i < preguntasPorEtapa[stage.id]!.length; i++)
                        [
                          '${i + 1}',
                          preguntasPorEtapa[stage.id]![i]['nombre'] ?? '',
                          preguntasPorEtapa[stage.id]![i]['descripcion'] ?? 'Sin descripción',
                        ],
                    ],
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: _getStageColor(stage.get('color') ?? 'blue'),
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.all(8),
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                  )
                else
                  pw.Text(
                    'No hay criterios definidos para esta etapa',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildSignaturesPage() {
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Header(
          level: 1,
          text: 'VALIDACIÓN OFICIAL',
        ),
        pw.SizedBox(height: 50),
        pw.Text(
          'El presente documento es validado y certificado por el comité organizador '
          'del Certamen de Nochebuena como reflejo fiel de los resultados obtenidos.',
          style: pw.TextStyle(fontSize: 14),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 80),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Presidente del Comité Organizador',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Coordinador del Certamen',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 50),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Representante Municipal',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Presidente del Jurado',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 100),
        pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Sello Oficial del Certamen de Nochebuena',
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildParticipantCoverPage({
    required String participantName,
    required String participantId,
    required String fecha,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topCenter,
          end: pw.Alignment.bottomCenter,
          colors: [PdfColors.green, PdfColors.green800],
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'REPORTE INDIVIDUAL',
            style: pw.TextStyle(
              fontSize: 24,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            participantName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 32,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'ID: $participantId',
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 100,
            height: 100,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColors.white,
            ),
            child: pw.Center(
              child: pw.Text(
                participantName.isNotEmpty ? participantName[0].toUpperCase() : '?',
                style: pw.TextStyle(
                  fontSize: 48,
                  color: PdfColors.green800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Text(
            'Generado el: $fecha',
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildParticipantSummaryPage({
    required String participantName,
    required int totalCalificaciones,
    required List<Map<String, dynamic>> estadisticasPorEtapa,
  }) {
    double promedioGeneral = 0;
    if (estadisticasPorEtapa.isNotEmpty) {
      final suma = estadisticasPorEtapa.map((e) => e['promedio'] as double).reduce((a, b) => a + b);
      promedioGeneral = suma / estadisticasPorEtapa.length;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'RESUMEN GENERAL',
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Participante:',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    participantName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    children: [
                      // Gráfico circular simple
                      pw.Container(
                        width: 150,
                        height: 150,
                        child: pw.Stack(
                          children: [
                            pw.Center(
                              child: pw.Text(
                                promedioGeneral.toStringAsFixed(1),
                                style: pw.TextStyle(
                                  fontSize: 48,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue700,
                                ),
                              ),
                            ),
                            // Simulamos un arco con un círculo parcial
                            pw.Center(
                              child: pw.Transform.rotate(
                                angle: 3.14159,
                                child: pw.Container(
                                  width: 140,
                                  height: 140,
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(
                                      color: _getScoreColor(promedioGeneral),
                                      width: 10,
                                    ),
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildStatItem('Promedio General', '${promedioGeneral.toStringAsFixed(2)}/10.00'),
                            _buildStatItem('Total Calificaciones', totalCalificaciones.toString()),
                            _buildStatItem('Etapas Evaluadas', estadisticasPorEtapa.length.toString()),
                            _buildStatItem('Estado', 'ACTIVA'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Header(
          level: 2,
          text: 'RENDIMIENTO POR ETAPA',
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          data: [
            ['ETAPA', 'TIPO', 'PROMEDIO', 'CALIFICACIONES', 'MÁXIMO'],
            for (var etapa in estadisticasPorEtapa)
              [
                etapa['nombre'] ?? '',
                etapa['tipo'] ?? '',
                '${etapa['promedio']?.toStringAsFixed(2) ?? '0.00'}',
                '${etapa['totalCalificaciones'] ?? 0}',
                '${etapa['maxScore'] ?? 10}',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.green700,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
      ],
    );
  }

  pw.Row _buildStatItem(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
      ],
    );
  }

  PdfColor _getScoreColor(double score) {
    if (score >= 9) return PdfColors.green;
    if (score >= 7) return PdfColors.lightGreen;
    if (score >= 5) return PdfColors.orange;
    return PdfColors.red;
  }

  pw.Widget _buildParticipantStageDetailPage({
    required Map<String, dynamic> etapa,
    required List<QueryDocumentSnapshot> calificaciones,
    required List<Map<String, dynamic>> preguntas,
  }) {
    // Agrupar calificaciones por criterio
    final Map<String, List<double>> calificacionesPorCriterio = {};
    final Map<String, List<String>> comentariosPorCriterio = {};
    
    for (var pregunta in preguntas) {
      calificacionesPorCriterio[pregunta['id']] = [];
      comentariosPorCriterio[pregunta['id']] = [];
    }
    
    for (var calificacion in calificaciones) {
      final criterioId = calificacion.get('criterioId');
      final puntaje = calificacion.get('puntaje');
      final comentario = calificacion.get('comentario');
      
      if (criterioId != null && puntaje != null) {
        double valor = 0;
        if (puntaje is int) {
          valor = puntaje.toDouble();
        } else if (puntaje is double) {
          valor = puntaje;
        } else if (puntaje is num) {
          valor = puntaje.toDouble();
        }
        
        if (calificacionesPorCriterio.containsKey(criterioId)) {
          calificacionesPorCriterio[criterioId]!.add(valor);
        }
        
        if (comentario != null && comentario.toString().isNotEmpty) {
          comentariosPorCriterio[criterioId]?.add(comentario.toString());
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: etapa['nombre'] ?? 'Etapa',
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Tipo: ${etapa['tipo']?.toString().toUpperCase() ?? ''}',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Promedio en esta etapa: ${etapa['promedio']?.toStringAsFixed(2) ?? '0.00'} / ${etapa['maxScore'] ?? 10}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
        pw.SizedBox(height: 15),
        
        // Tabla de calificaciones por criterio
        if (preguntas.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Calificaciones por criterio:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                data: [
                  ['CRITERIO', 'PROMEDIO', 'CALIFICACIONES', 'COMENTARIOS'],
                  for (var pregunta in preguntas)
                    [
                      pregunta['nombre'] ?? pregunta['id'],
                      calificacionesPorCriterio[pregunta['id']]?.isNotEmpty ?? false
                          ? (calificacionesPorCriterio[pregunta['id']]!.reduce((a, b) => a + b) / 
                             calificacionesPorCriterio[pregunta['id']]!.length).toStringAsFixed(2)
                          : '0.00',
                      '${calificacionesPorCriterio[pregunta['id']]?.length ?? 0}',
                      '${comentariosPorCriterio[pregunta['id']]?.length ?? 0}',
                    ],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.purple700,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
            ],
          ),
        
        pw.SizedBox(height: 20),
        
        // Detalle de calificaciones individuales
        if (calificaciones.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Detalle de calificaciones:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                data: [
                  ['JUEZ', 'CRITERIO', 'PUNTAJE', 'FECHA'],
                  for (var calificacion in calificaciones.take(20)) // Limitar a 20 para no saturar
                    [
                      calificacion.get('juezId') ?? 'N/A',
                      _getPreguntaNombre(calificacion.get('criterioId') ?? '', preguntas),
                      '${calificacion.get('puntaje')?.toString() ?? '0'}',
                      _formatPdfDate(calificacion.get('fecha')),
                    ],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
              if (calificaciones.length > 20)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    '... y ${calificaciones.length - 20} calificaciones más',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _getPreguntaNombre(String criterioId, List<Map<String, dynamic>> preguntas) {
    for (var pregunta in preguntas) {
      if (pregunta['id'] == criterioId) {
        return pregunta['nombre'] ?? criterioId;
      }
    }
    return criterioId;
  }

  pw.Widget _buildCommentsPage({
    required String participantName,
    required List<QueryDocumentSnapshot> comentarios,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'COMENTARIOS DE LOS JUECES',
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Para: $participantName',
          style: pw.TextStyle(
            fontSize: 12,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.SizedBox(height: 20),

        for (var comentario in comentarios)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Juez: ${comentario.get('juezId') ?? 'N/A'}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Etapa: ${comentario.get('etapaId') ?? 'N/A'}',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  comentario.get('comentario') ?? 'Sin comentario',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Fecha: ${_formatPdfDate(comentario.get('fecha'))}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatPdfDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(date.toDate());
      }
      return 'Fecha no disponible';
    } catch (e) {
      return 'Fecha no disponible';
    }
  }

  // ============ FUNCIONES PARA RANKING REPORT ============

  pw.Widget _buildRankingCoverPage({
    required String fecha,
    required int totalParticipantes,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topCenter,
          end: pw.Alignment.bottomCenter,
          colors: [PdfColors.orange, PdfColors.orange800],
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'RANKING FINAL',
            style: pw.TextStyle(
              fontSize: 36,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'CERTAMEN DE NOCHEBUENA',
            style: pw.TextStyle(
              fontSize: 20,
              color: PdfColors.white,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x1AFFFFFF),
              borderRadius: pw.BorderRadius.circular(15),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'RESULTADOS OFICIALES',
                  style: pw.TextStyle(
                    fontSize: 24,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Fecha: $fecha',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Total participantes: $totalParticipantes',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Text(
            '🥇 🥈 🥉',
            style: pw.TextStyle(fontSize: 40),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTop10Page({
    required List<Map<String, dynamic>> participantes,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'TOP 10 FINAL',
          textStyle: pw.TextStyle(  // ← ¡ERROR! Header NO tiene parámetro 'style'!
            color: PdfColors.orange800,
            fontSize: 22,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Los 10 mejores participantes del certamen:',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        
        for (var i = 0; i < participantes.length && i < 10; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: i == 0
                  ? PdfColors.amber50
                  : i == 1
                      ? PdfColors.grey50
                      : i == 2
                          ? PdfColors.orange50
                          : PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(
                color: i == 0
                    ? PdfColors.amber300
                    : i == 1
                        ? PdfColors.grey300
                        : i == 2
                            ? PdfColors.orange300
                            : PdfColors.grey300,
                width: 1,
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}',
                  style: pw.TextStyle(
                    fontSize: i < 3 ? 24 : 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        participantes[i]['nombre'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        'ID: ${participantes[i]['idInterno'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${participantes[i]['promedio']?.toStringAsFixed(2) ?? '0.00'} pts',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: i == 0
                            ? PdfColors.amber800
                            : i == 1
                                ? PdfColors.grey800
                                : i == 2
                                    ? PdfColors.orange800
                                    : PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      '${participantes[i]['totalCalificaciones'] ?? 0} calificaciones',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildFullRankingPage({
    required List<Map<String, dynamic>> participantes,
  }) {
    final data = [
      ['POSICIÓN', 'PARTICIPANTE', 'ID', 'PROMEDIO', 'CALIFICACIONES'],
      for (var i = 0; i < participantes.length; i++)
        [
          '${i + 1}',
          participantes[i]['nombre'] ?? '',
          participantes[i]['idInterno'] ?? '',
          '${participantes[i]['promedio']?.toStringAsFixed(2) ?? '0.00'}',
          '${participantes[i]['totalCalificaciones'] ?? 0}',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'RANKING COMPLETO',
          textStyle: pw.TextStyle(
            color: PdfColors.blue800,
            fontSize: 20,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Lista completa de todos los participantes ordenados por promedio:',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 11,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blue700,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 1,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildStageRankingForPress({
    required String stageName,
    required List<Map<String, dynamic>> ranking,
  }) {
    final data = [
      ['POSICIÓN', 'PARTICIPANTE', 'ID', 'PROMEDIO'],
      for (var i = 0; i < ranking.length && i < 10; i++)
        [
          '${i + 1}',
          ranking[i]['nombre'] ?? '',
          ranking[i]['idInterno'] ?? '',
          '${ranking[i]['promedio']?.toStringAsFixed(2) ?? '0.00'}',
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: 'ETAPA: $stageName',
          textStyle: pw.TextStyle(
            color: PdfColors.purple800,
            fontSize: 20,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Top 10 de la etapa $stageName:',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 11,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.purple700,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(8),
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 1,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}