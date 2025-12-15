import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/calificacion_model.dart';
import './user_session.dart';

class CalificacionServiceOrganizado {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Guardar en estructura organizada: calificaciones/participanteId/etapas/etapaId/criterios
  Future<void> guardarCalificacionOrganizada(Calificacion calificacion) async {
    try {
      print('💾 [Organizado] Guardando calificación...');
      print('   Participante: ${calificacion.participanteId}');
      print('   Etapa: ${calificacion.etapaId}');
      print('   Criterio: ${calificacion.criterioId}');
      print('   Puntaje: ${calificacion.puntaje}');
      
      // ID único para el documento
      final docId = '${calificacion.participanteId}_${calificacion.etapaId}_${calificacion.juezId}_${calificacion.criterioId}';
      
      // Datos completos
      final datos = {
        'juezId': calificacion.juezId,
        'participanteId': calificacion.participanteId,
        'etapaId': calificacion.etapaId,
        'criterioId': calificacion.criterioId,
        'puntaje': calificacion.puntaje,
        'comentario': calificacion.comentario ?? '',
        'fecha': FieldValue.serverTimestamp(),
        'juezNombre': UserSession.displayName,
        'juezNumero': UserSession.numjuez ?? '',
        'isSynced': true,
        'syncTimestamp': FieldValue.serverTimestamp(),
      };
      
      // Guardar en estructura organizada
      await _firestore
          .collection('calificaciones_organizadas')  // Nueva colección organizada
          .doc(calificacion.participanteId)          // Documento por participante
          .collection('etapas')                      // Subcolección de etapas
          .doc(calificacion.etapaId)                 // Documento por etapa
          .collection('criterios')                   // Subcolección de criterios
          .doc(docId)                                // Documento único
          .set(datos, SetOptions(merge: true));
      
      print('✅ Calificación guardada en estructura organizada');
      print('   Ruta: calificaciones_organizadas/${calificacion.participanteId}/etapas/${calificacion.etapaId}/criterios/$docId');
      
      // También guardar en estructura plana para compatibilidad
      await _guardarCalificacionPlana(calificacion);
      
    } catch (e) {
      print('❌ Error guardando calificación organizada: $e');
      rethrow;
    }
  }

  // También guardar en estructura plana (backup/compatibilidad)
  Future<void> _guardarCalificacionPlana(Calificacion calificacion) async {
    try {
      await _firestore
          .collection('calificaciones')  // Colección plana original
          .doc(calificacion.id)
          .set(calificacion.toFirestorePlana());
      
      print('📝 También guardado en estructura plana (compatibilidad)');
    } catch (e) {
      print('⚠️ Error guardando en estructura plana (no crítico): $e');
    }
  }

  // Obtener calificaciones de un juez para un participante y etapa
  Future<List<Calificacion>> getCalificacionesJuezParticipanteEtapa({
    required String participanteId,
    required String etapaId,
  }) async {
    try {
      final juezId = UserSession.firebaseId;
      if (juezId == null) return [];
      
      print('🔍 [Organizado] Buscando calificaciones para:');
      print('   Juez: $juezId');
      print('   Participante: $participanteId');
      print('   Etapa: $etapaId');
      
      final snapshot = await _firestore
          .collection('calificaciones_organizadas')
          .doc(participanteId)
          .collection('etapas')
          .doc(etapaId)
          .collection('criterios')
          .where('juezId', isEqualTo: juezId)
          .get();
      
      print('📊 Calificaciones encontradas: ${snapshot.docs.length}');
      
      return snapshot.docs
          .map((doc) => Calificacion.fromFirestoreOrganizada(doc.data(), doc.id))
          .toList();
      
    } catch (e) {
      print('❌ Error obteniendo calificaciones organizadas: $e');
      
      // Fallback: buscar en estructura plana
      try {
        print('🔄 Intentando fallback a estructura plana...');
        final snapshot = await _firestore
            .collection('calificaciones')
            .where('juezId', isEqualTo: UserSession.firebaseId)
            .where('participanteId', isEqualTo: participanteId)
            .where('etapaId', isEqualTo: etapaId)
            .get();
        
        return snapshot.docs
            .map((doc) => Calificacion.fromFirestorePlana(doc.data(), doc.id))
            .toList();
      } catch (e2) {
        print('❌ También falló el fallback: $e2');
        return [];
      }
    }
  }

  // Verificar si ya calificó un criterio
  Future<bool> criterioYaCalificado({
    required String participanteId,
    required String etapaId,
    required String criterioId,
  }) async {
    try {
      final juezId = UserSession.firebaseId;
      if (juezId == null) return false;
      
      final docId = '${participanteId}_${etapaId}_${juezId}_${criterioId}';
      
      final doc = await _firestore
          .collection('calificaciones_organizadas')
          .doc(participanteId)
          .collection('etapas')
          .doc(etapaId)
          .collection('criterios')
          .doc(docId)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('❌ Error verificando calificación: $e');
      return false;
    }
  }

  // Obtener promedio de un participante en una etapa
  Future<double> getPromedioParticipanteEtapa({
    required String participanteId,
    required String etapaId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('calificaciones_organizadas')
          .doc(participanteId)
          .collection('etapas')
          .doc(etapaId)
          .collection('criterios')
          .get();
      
      if (snapshot.docs.isEmpty) return 0.0;
      
      double total = 0;
      int count = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final puntaje = (data['puntaje'] as num?)?.toDouble() ?? 0.0;
        total += puntaje;
        count++;
      }
      
      return count > 0 ? total / count : 0.0;
    } catch (e) {
      print('❌ Error calculando promedio: $e');
      return 0.0;
    }
  }

  // Obtener resumen por participante
  Future<Map<String, dynamic>> getResumenParticipante(String participanteId) async {
    try {
      final etapasSnapshot = await _firestore
          .collection('calificaciones_organizadas')
          .doc(participanteId)
          .collection('etapas')
          .get();
      
      final resumen = <String, dynamic>{
        'participanteId': participanteId,
        'totalEtapas': etapasSnapshot.docs.length,
        'etapas': [],
        'promedioGeneral': 0.0,
      };
      
      double totalGeneral = 0;
      int countGeneral = 0;
      
      for (final etapaDoc in etapasSnapshot.docs) {
        final criteriosSnapshot = await etapaDoc.reference
            .collection('criterios')
            .get();
        
        double totalEtapa = 0;
        for (final criterioDoc in criteriosSnapshot.docs) {
          final data = criterioDoc.data();
          totalEtapa += (data['puntaje'] as num?)?.toDouble() ?? 0.0;
        }
        
        final promedioEtapa = criteriosSnapshot.docs.isNotEmpty 
            ? totalEtapa / criteriosSnapshot.docs.length 
            : 0.0;
        
        (resumen['etapas'] as List).add({
          'etapaId': etapaDoc.id,
          'totalCriterios': criteriosSnapshot.docs.length,
          'promedioEtapa': promedioEtapa,
        });
        
        totalGeneral += totalEtapa;
        countGeneral += criteriosSnapshot.docs.length;
      }
      
      resumen['promedioGeneral'] = countGeneral > 0 ? totalGeneral / countGeneral : 0.0;
      
      return resumen;
    } catch (e) {
      print('❌ Error obteniendo resumen: $e');
      return {
        'participanteId': participanteId,
        'totalEtapas': 0,
        'etapas': [],
        'promedioGeneral': 0.0,
      };
    }
  }
}