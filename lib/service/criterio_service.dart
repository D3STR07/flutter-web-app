import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/criterio_model.dart';

class CriterioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Criterio>> getCriteriosDeEtapa(String etapaId) async {
    print('🔍 [CriterioService] Buscando criterios para etapa: $etapaId');
    
    try {
      // Verificar que la etapa existe
      final etapaDoc = await _firestore.collection('stages').doc(etapaId).get();
      
      if (!etapaDoc.exists) {
        print('❌ Etapa no encontrada por ID: $etapaId');
        // Intentar buscar por nombre
        final etapasSnapshot = await _firestore
            .collection('stages')
            .where('name', isEqualTo: etapaId)
            .limit(1)
            .get();
        
        if (etapasSnapshot.docs.isEmpty) {
          throw Exception('Etapa "$etapaId" no encontrada en Firebase');
        }
        
        final etapaRealId = etapasSnapshot.docs.first.id;
        print('✅ Etapa encontrada por nombre. ID real: $etapaRealId');
        
        // Ahora buscar criterios con el ID real
        return await _getCriteriosDeEtapaId(etapaRealId);
      }
      
      print('✅ Etapa encontrada por ID');
      return await _getCriteriosDeEtapaId(etapaId);
      
    } catch (e) {
      print('❌ [CriterioService] Error: $e');
      rethrow;
    }
  }

  Future<List<Criterio>> _getCriteriosDeEtapaId(String etapaId) async {
    try {
      print('🔍 Buscando en: stages/$etapaId/questions');
      
      final snapshot = await _firestore
          .collection('stages')
          .doc(etapaId)
          .collection('questions')  // ← IMPORTANTE: "questions" no "preguntas"
          .orderBy('order')
          .get();
      
      print('📊 Documents encontrados en questions: ${snapshot.docs.length}');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ La colección stages/$etapaId/questions está vacía');
        print('   Verifica que:');
        print('   1. La subcolección se llama "questions" (no "preguntas")');
        print('   2. Hay documentos dentro de ella');
        print('   3. Cada documento tiene: text, order, maxScore');
        return [];
      }
      
      // Mostrar cada documento para debug
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('   📝 ${doc.id}:');
        print('      text: ${data['text']}');
        print('      order: ${data['order']}');
        print('      maxScore: ${data['maxScore']}');
      }
      
      // Convertir a modelos Criterio
      final criterios = snapshot.docs.map((doc) {
        final data = doc.data();
        return Criterio(
          id: doc.id,
          etapaId: etapaId,
          text: data['text']?.toString() ?? 'Sin nombre',
          order: (data['order'] as int?) ?? 0,
          maxScore: (data['maxScore'] as num?)?.toDouble() ?? 10.0,
          createdAt: data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate() 
              : null,
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
      
      print('✅ Criterios procesados: ${criterios.length}');
      return criterios;
        
    } catch (e) {
      print('❌ Error en _getCriteriosDeEtapaId: $e');
      
      // Si falla con "questions", probar con "preguntas" por si acaso
      if (e.toString().contains('questions')) {
        print('🔄 Probando con "preguntas" en lugar de "questions"');
        try {
          final snapshot = await _firestore
              .collection('stages')
              .doc(etapaId)
              .collection('preguntas')
              .orderBy('order')
              .get();
          
          if (snapshot.docs.isNotEmpty) {
            print('✅ Encontrado en "preguntas"');
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return Criterio(
                id: doc.id,
                etapaId: etapaId,
                text: data['text']?.toString() ?? 'Sin nombre',
                order: (data['order'] as int?) ?? 0,
                maxScore: (data['maxScore'] as num?)?.toDouble() ?? 10.0,
              );
            }).toList();
          }
        } catch (e2) {
          print('❌ También falló con "preguntas": $e2');
        }
      }
      
      rethrow;
    }
  }

  Stream<List<Criterio>> getCriteriosDeEtapaStream(String etapaId) {
    return _firestore
        .collection('stages')
        .doc(etapaId)
        .collection('questions')  // ← "questions"
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              return Criterio(
                id: doc.id,
                etapaId: etapaId,
                text: data['text']?.toString() ?? 'Sin nombre',
                order: (data['order'] as int?) ?? 0,
                maxScore: (data['maxScore'] as num?)?.toDouble() ?? 10.0,
              );
            })
            .toList());
  }

  Future<Criterio?> getCriterioById(String etapaId, String criterioId) async {
    try {
      final doc = await _firestore
          .collection('stages')
          .doc(etapaId)
          .collection('questions')  // ← "questions"
          .doc(criterioId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return Criterio(
          id: doc.id,
          etapaId: etapaId,
          text: data['text']?.toString() ?? 'Sin nombre',
          order: (data['order'] as int?) ?? 0,
          maxScore: (data['maxScore'] as num?)?.toDouble() ?? 10.0,
        );
      }
      return null;
    } catch (e) {
      print('Error obteniendo criterio: $e');
      return null;
    }
  }
}