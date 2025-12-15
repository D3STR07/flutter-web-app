import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/calificacion_model.dart';
import './user_session.dart';

class CalificacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'calificaciones';

  // Guardar en Firebase
  Future<void> guardarCalificacionFirebase(Calificacion calificacion) async {
    try {
      print('💾 Guardando calificación en Firebase:');
      print('   ID: ${calificacion.id}');
      print('   Juez: ${calificacion.juezId}');
      print('   Participante: ${calificacion.participanteId}');
      print('   Etapa: ${calificacion.etapaId}');
      print('   Criterio: ${calificacion.criterioId}');
      print('   Puntaje: ${calificacion.puntaje}');
      
      await _firestore
          .collection(collectionName)
          .doc(calificacion.id)
          .set(calificacion.toFirestore());
          
      print('✅ Calificación guardada en Firebase');
    } catch (e) {
      print('❌ Error guardando calificación en Firebase: $e');
      throw Exception('No se pudo guardar la calificación: $e');
    }
  }

  // Obtener calificaciones del juez para un participante
  Stream<List<Calificacion>> getCalificacionesJuezParticipante({
    required String participanteId,
    required String etapaId,
  }) {
    print('🔍 Buscando calificaciones para:');
    print('   Juez: ${UserSession.firebaseId}');
    print('   Participante: $participanteId');
    print('   Etapa: $etapaId');
    
    return _firestore
        .collection(collectionName)
        .where('juezId', isEqualTo: UserSession.firebaseId)
        .where('participanteId', isEqualTo: participanteId)
        .where('etapaId', isEqualTo: etapaId)
        .snapshots()
        .map((snapshot) {
          print('📊 Calificaciones encontradas: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Calificacion.fromFirestoreWithId(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
        });
  }

  // Verificar si ya calificó un criterio
  Future<bool> criterioYaCalificado({
    required String participanteId,
    required String etapaId,
    required String criterioId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('juezId', isEqualTo: UserSession.firebaseId)
          .where('participanteId', isEqualTo: participanteId)
          .where('etapaId', isEqualTo: etapaId)
          .where('criterioId', isEqualTo: criterioId)
          .limit(1)
          .get();

      final yaCalificado = snapshot.docs.isNotEmpty;
      print('🔍 Criterio ya calificado? $yaCalificado');
      return yaCalificado;
    } catch (e) {
      print('Error verificando calificación: $e');
      return false;
    }
  }

  // Eliminar calificación
  Future<void> eliminarCalificacion(String calificacionId) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(calificacionId)
          .delete();
    } catch (e) {
      print('Error eliminando calificación: $e');
      throw Exception('No se pudo eliminar la calificación');
    }
  }

  // Obtener todas las calificaciones del juez
  Stream<List<Calificacion>> getCalificacionesDelJuez() {
    return _firestore
        .collection(collectionName)
        .where('juezId', isEqualTo: UserSession.firebaseId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Calificacion.fromFirestoreWithId(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}