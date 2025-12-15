import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Definiciones de colecciones
const String collectionStages = 'stages';
const String collectionCalificaciones = 'calificaciones';

class StageControlScreen extends StatefulWidget {
  const StageControlScreen({super.key});

  @override
  State<StageControlScreen> createState() => _StageControlScreenState();
}

class _StageControlScreenState extends State<StageControlScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎭 Control de Etapas'),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showInfoDialog,
            tooltip: 'Información',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de Etapa Activa
            _buildActiveStageInfo(),
            const SizedBox(height: 24),
            
            // Listado de Todas las Etapas
            _buildSectionHeader(
              title: '📋 Todas las Etapas',
              subtitle: 'Gestiona el estado de cada etapa',
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: _buildStagesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStageDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Etapa'),
        backgroundColor: Colors.purple.shade700,
      ),
    );
  }

  Widget _buildActiveStageInfo() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collectionStages)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoActiveStageCard();
        }

        final stageDoc = snapshot.data!.docs.first;
        final stageData = stageDoc.data() as Map<String, dynamic>;
        final stageId = stageDoc.id;
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade700,
                Colors.deepPurple.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade700.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ETAPA ACTIVA ACTUAL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'EN PROGRESO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stageData['name']?.toString().toUpperCase() ?? 'ETAPA SIN NOMBRE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              if (stageData['subtitle'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    stageData['subtitle'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Tipo:',
                          stageData['type']?.toString().toUpperCase() ?? 'NO DEFINIDO',
                          Icons.category,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Puntaje Máx:',
                          '${stageData['maxScore'] ?? 10} puntos',
                          Icons.star,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          'Orden:',
                          '${stageData['order'] ?? 0}',
                          Icons.sort,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      FutureBuilder<int>(
                        future: _getStageCalificationsCount(stageId),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'CALIFICACIONES',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStageActions(stageId, stageData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStageActions(String stageId, Map<String, dynamic> stageData) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _finalizeStage(stageId),
            icon: const Icon(Icons.stop_circle, size: 20),
            label: const Text('FINALIZAR ETAPA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _closeStage(stageId),
            icon: const Icon(Icons.lock, size: 20),
            label: const Text('CERRAR ETAPA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
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
    );
  }

  Widget _buildStagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collectionStages)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyStagesList();
        }

        final stages = snapshot.data!.docs;

        return ListView.separated(
          itemCount: stages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final stageDoc = stages[index];
            final stageData = stageDoc.data() as Map<String, dynamic>;
            final stageId = stageDoc.id;
            final status = stageData['status']?.toString() ?? 'closed';
            
            return _buildStageCard(stageId, stageData, status);
          },
        );
      },
    );
  }

  Widget _buildStageCard(String stageId, Map<String, dynamic> stageData, String status) {
    final isActive = status == 'active';
    final isFinished = status == 'finished';
    final isClosed = status == 'closed';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isActive) {
      statusColor = Colors.green.shade700;
      statusText = 'ACTIVA';
      statusIcon = Icons.play_arrow;
    } else if (isFinished) {
      statusColor = Colors.blue.shade700;
      statusText = 'FINALIZADA';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.grey.shade700;
      statusText = 'CERRADA';
      statusIcon = Icons.lock;
    }
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.purple.shade300 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageData['name'] ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.purple.shade800 : Colors.grey.shade800,
                        ),
                      ),
                      if (stageData['subtitle'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            stageData['subtitle'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStageInfoChip(
                  'Tipo: ${stageData['type']?.toString().toUpperCase() ?? 'N/A'}',
                  Icons.category,
                ),
                const SizedBox(width: 8),
                _buildStageInfoChip(
                  'Máx: ${stageData['maxScore'] ?? 10} pts',
                  Icons.star,
                ),
                const SizedBox(width: 8),
                _buildStageInfoChip(
                  'Orden: ${stageData['order'] ?? 0}',
                  Icons.sort,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FutureBuilder<int>(
                  future: _getStageCalificationsCount(stageId),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calificaciones registradas:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (stageData['createdAt'] != null)
                      Text(
                        _formatDate(stageData['createdAt']),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildStageCardActions(stageId, status),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCardActions(String stageId, String currentStatus) {
    final isActive = currentStatus == 'active';
    final isFinished = currentStatus == 'finished';
    final isClosed = currentStatus == 'closed';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isActive && !isFinished) // Si está cerrada o es nueva
          ElevatedButton(
            onPressed: () => _activateStage(stageId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ACTIVAR'),
          ),
        
        if (isActive) // Si está activa
          OutlinedButton(
            onPressed: () => _finalizeStage(stageId),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.amber.shade700),
              foregroundColor: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('FINALIZAR'),
          ),
        
        if (!isClosed && !isActive) // Si está finalizada
          OutlinedButton(
            onPressed: () => _closeStage(stageId),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.shade700),
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CERRAR'),
          ),
        
        if (isClosed || isFinished) // Si está cerrada o finalizada
          IconButton(
            onPressed: () => _reopenStage(stageId),
            icon: Icon(Icons.refresh, color: Colors.blue.shade700),
            tooltip: 'Reabrir',
          ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Text('Cargando etapa activa...'),
        ],
      ),
    );
  }

  Widget _buildNoActiveStageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'NO HAY ETAPA ACTIVA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay ninguna etapa en progreso actualmente. '
            'Activa una etapa para que los jueces puedan calificar.',
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _showActivateStageDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('ACTIVAR UNA ETAPA'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStagesList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No hay etapas creadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea la primera etapa usando el botón +',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============ MÉTODOS DE ACCIÓN ============

  Future<void> _activateStage(String stageId) async {
    try {
      // Primero, desactivar cualquier etapa activa
      final activeStages = await _firestore
          .collection(collectionStages)
          .where('status', isEqualTo: 'active')
          .get();
      
      for (var doc in activeStages.docs) {
        await doc.reference.update({'status': 'finished'});
      }
      
      // Activar la etapa seleccionada
      await _firestore
          .collection(collectionStages)
          .doc(stageId)
          .update({'status': 'active'});
      
      _showSuccessSnackbar('✅ Etapa activada correctamente');
    } catch (e) {
      _showErrorSnackbar('❌ Error al activar etapa: $e');
    }
  }

  Future<void> _finalizeStage(String stageId) async {
    final confirmed = await _showConfirmationDialog(
      'Finalizar Etapa',
      '¿Estás seguro de finalizar esta etapa?\n\n'
      'Una vez finalizada:\n'
      '• Los jueces NO podrán seguir calificando\n'
      '• La etapa se marcará como completada\n'
      '• Los puntajes quedarán registrados',
    );
    
    if (confirmed) {
      try {
        await _firestore
            .collection(collectionStages)
            .doc(stageId)
            .update({'status': 'finished'});
        
        _showSuccessSnackbar('✅ Etapa finalizada correctamente');
      } catch (e) {
        _showErrorSnackbar('❌ Error al finalizar etapa: $e');
      }
    }
  }

  Future<void> _closeStage(String stageId) async {
    final confirmed = await _showConfirmationDialog(
      'Cerrar Etapa',
      '¿Estás seguro de cerrar esta etapa?\n\n'
      'Una vez cerrada:\n'
      '• NO se podrá reabrir para calificaciones\n'
      '• Los datos quedarán archivados\n'
      '• Solo se podrá consultar información',
    );
    
    if (confirmed) {
      try {
        await _firestore
            .collection(collectionStages)
            .doc(stageId)
            .update({'status': 'closed'});
        
        _showSuccessSnackbar('✅ Etapa cerrada correctamente');
      } catch (e) {
        _showErrorSnackbar('❌ Error al cerrar etapa: $e');
      }
    }
  }

  Future<void> _reopenStage(String stageId) async {
    final confirmed = await _showConfirmationDialog(
      'Reabrir Etapa',
      '¿Estás seguro de reabrir esta etapa?\n\n'
      'Al reabrir:\n'
      '• Volverá al estado FINALIZADA\n'
      '• Puedes activarla nuevamente si es necesario\n'
      '• Los datos se mantendrán intactos',
    );
    
    if (confirmed) {
      try {
        await _firestore
            .collection(collectionStages)
            .doc(stageId)
            .update({'status': 'finished'});
        
        _showSuccessSnackbar('✅ Etapa reabierta correctamente');
      } catch (e) {
        _showErrorSnackbar('❌ Error al reabrir etapa: $e');
      }
    }
  }

  Future<void> _showCreateStageDialog() async {
    final nameController = TextEditingController();
    final subtitleController = TextEditingController();
    final maxScoreController = TextEditingController(text: '10');
    final orderController = TextEditingController();
    final typeController = TextEditingController();
    
    String? selectedType = 'pasarela';
    
    final types = ['pasarela', 'entrevista', 'pregunta'];
    final colors = ['blue', 'red', 'green', 'purple', 'orange', 'indigo'];
    String? selectedColor = 'blue';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Crear Nueva Etapa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la etapa*',
                  hintText: 'Ej: ROPA CASUAL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Subtítulo',
                  hintText: 'Ej: 2DA ETAPA',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxScoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Puntaje Máx.*',
                        hintText: '10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Orden*',
                        hintText: '1, 2, 3...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Etapa*',
                  border: OutlineInputBorder(),
                ),
                items: types.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedType = value;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
                items: colors.map((color) {
                  return DropdownMenuItem(
                    value: color,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getColorFromString(color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(color),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedColor = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || 
                  maxScoreController.text.isEmpty || 
                  orderController.text.isEmpty) {
                _showErrorSnackbar('❌ Completa los campos obligatorios');
                return;
              }
              
              try {
                await _firestore.collection(collectionStages).add({
                  'name': nameController.text,
                  'subtitle': subtitleController.text.isNotEmpty 
                      ? subtitleController.text 
                      : null,
                  'maxScore': int.parse(maxScoreController.text),
                  'order': int.parse(orderController.text),
                  'type': selectedType,
                  'color': selectedColor,
                  'status': 'closed', // Nueva etapa empieza cerrada
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                Navigator.pop(context);
                _showSuccessSnackbar('✅ Etapa creada correctamente');
              } catch (e) {
                _showErrorSnackbar('❌ Error al crear etapa: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            child: const Text('CREAR ETAPA'),
          ),
        ],
      ),
    );
  }

  Future<int> _getStageCalificationsCount(String stageId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionCalificaciones)
          .where('etapaId', isEqualTo: stageId)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(date.toDate());
      }
      return 'Fecha no disponible';
    } catch (e) {
      return 'Fecha no disponible';
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'blue': return Colors.blue;
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'purple': return Colors.purple;
      case 'orange': return Colors.orange;
      case 'indigo': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showActivateStageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activar Etapa'),
        content: const Text('Selecciona una etapa para activar. '
            'Solo puede haber UNA etapa activa a la vez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aquí podríamos navegar a la lista de etapas
            },
            child: const Text('VER ETAPAS'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 Estados de Etapa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusInfoRow(
              '🟢 ACTIVA',
              'Los jueces PUEDEN calificar',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildStatusInfoRow(
              '🔵 FINALIZADA',
              'Etapa completada, NO se puede calificar',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStatusInfoRow(
              '⚫ CERRADA',
              'Etapa archivada, solo consulta',
              Colors.grey,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '📌 Notas importantes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('• Solo UNA etapa puede estar ACTIVA a la vez'),
            const Text('• Al activar una etapa, la anterior se FINALIZA'),
            const Text('• Las etapas CERRADAS no pueden reabrirse'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoRow(String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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