import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/etapa_model.dart';

class EtapaRemoteSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collectionEtapas = 'stages';
  static const String collectionEvento = 'evento';

  // Obtener todas las etapas
  Stream<List<Etapa>> getEtapasStream() {
    return _db
        .collection(collectionEtapas)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Etapa.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  // Obtener etapa activa
  Stream<Etapa?> getEtapaActivaStream() {
    return _db
        .collection(collectionEtapas)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Etapa.fromFirestore(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    });
  }

  // Obtener etapas una vez (para sincronización)
  Future<List<Etapa>> getEtapas() async {
    try {
      final snapshot = await _db
          .collection(collectionEtapas)
          .orderBy('order')
          .get();
      
      return snapshot.docs
          .map((doc) => Etapa.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error obteniendo etapas de Firebase: $e');
      throw e;
    }
  }

  // Guardar etapa en Firebase
  Future<String> saveEtapa(Etapa etapa) async {
    try {
      // Si ya tiene ID (viene de local), actualizar
      if (etapa.id.isNotEmpty && !etapa.id.startsWith('local_')) {
        await _db
            .collection(collectionEtapas)
            .doc(etapa.id)
            .set(etapa.toFirestore(), SetOptions(merge: true));
        return etapa.id;
      } else {
        // Crear nuevo documento
        final docRef = _db.collection(collectionEtapas).doc();
        await docRef.set(etapa.toFirestore());
        return docRef.id;
      }
    } catch (e) {
      print('Error guardando etapa en Firebase: $e');
      throw e;
    }
  }

  // Actualizar etapa
  Future<void> updateEtapa(Etapa etapa) async {
    try {
      await _db
          .collection(collectionEtapas)
          .doc(etapa.id)
          .update(etapa.toFirestore());
    } catch (e) {
      print('Error actualizando etapa en Firebase: $e');
      throw e;
    }
  }

  // Activar etapa
  Future<bool> activarEtapa(String etapaId, String userId, String userName) async {
    try {
      // 1. Obtener todas las etapas
      final etapasSnapshot = await _db
          .collection(collectionEtapas)
          .get();

      final batch = _db.batch();

      // 2. Finalizar etapas activas
      for (final doc in etapasSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'active') {
          batch.update(doc.reference, {
            'status': 'finished',
            'fechaFin': FieldValue.serverTimestamp(),
          });
        }
      }

      // 3. Activar la nueva etapa
      final etapaRef = _db.collection(collectionEtapas).doc(etapaId);
      batch.update(etapaRef, {
        'status': 'active',
        'fechaInicio': FieldValue.serverTimestamp(),
        'fechaFin': null,
      });

      // 4. Actualizar evento actual
      await _db.collection(collectionEvento).doc('estadoActual').set({
        'etapaActivaId': etapaId,
        'ultimoCambio': FieldValue.serverTimestamp(),
        'cambiadoPor': userName,
      }, SetOptions(merge: true));

      await batch.commit();
      return true;

    } catch (e) {
      print('❌ Error activando etapa en Firebase: $e');
      throw e;
    }
  }

  // Finalizar etapa activa
  Future<bool> finalizarEtapaActiva(String userId, String userName) async {
    try {
      final snapshot = await _db
          .collection(collectionEtapas)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final etapaRef = snapshot.docs.first.reference;
      await etapaRef.update({
        'status': 'finished',
        'fechaFin': FieldValue.serverTimestamp(),
      });

      // Limpiar etapa activa del evento
      await _db.collection(collectionEvento).doc('estadoActual').set({
        'etapaActivaId': null,
        'etapaActivaNombre': 'Ninguna',
        'ultimoCambio': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error finalizando etapa en Firebase: $e');
      throw e;
    }
  }

  // Eliminar etapa
  Future<void> deleteEtapa(String etapaId) async {
    try {
      await _db
          .collection(collectionEtapas)
          .doc(etapaId)
          .delete();
    } catch (e) {
      print('Error eliminando etapa en Firebase: $e');
      throw e;
    }
  }

  // Verificar conexión
  Future<bool> hasConnection() async {
    try {
      await _db.collection(collectionEtapas).limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Obtener usuario actual
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  String? getCurrentUserName() {
    return _auth.currentUser?.displayName ?? _auth.currentUser?.email;
  }
}