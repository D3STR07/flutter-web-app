import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:reina_nochebuena/service/user_session.dart';
import '../data/models/participante_model.dart';
import './local_database.dart';
import './sync_service.dart';

class ParticipanteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalDatabase _localDb = LocalDatabase();
  final SyncService _syncService = SyncService();
  
  static const String collectionParticipantes = 'participantes';
  static const String collectionEvaluaciones = 'evaluaciones';

  // Obtener participantes activos - CORREGIDO
  Stream<List<Participante>> getParticipantesActivos() {
    print('🔍 Iniciando consulta de participantes activos...');
    
    return _db
        .collection(collectionParticipantes)
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .handleError((error) {
          print('❌ Error en consulta Firebase: $error');
          return Stream<List<Participante>>.empty();
        })
        .asyncMap((snapshot) async {
      
      // DEBUG: Ver qué trajo Firebase
      print('==========================================');
      print('📊 RESULTADO CONSULTA FIREBASE');
      print('==========================================');
      print('Filtro: activo = true');
      print('Documentos obtenidos: ${snapshot.docs.length}');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ Firebase devolvió 0 documentos');
      }
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('👤 ${data['idInterno']}: ${data['nombre']} - activo: ${data['activo']}');
      }
      print('==========================================');
      
      // 1. Procesar participantes de Firebase
      final participantesRemotos = snapshot.docs
          .map((doc) => Participante.fromFirestore(doc))
          .where((p) => p.activo) // Doble filtro por seguridad
          .toList();
      
      print('✅ ${participantesRemotos.length} participantes activos procesados');
      
      // 2. LIMPIAR INACTIVOS DEL CACHE ANTES DE GUARDAR
      try {
        await _localDb.removerParticipantesInactivos();
      } catch (e) {
        print('⚠️ Error limpiando inactivos: $e');
      }
      
      // 3. Guardar en cache SOLO si hay datos
      if (participantesRemotos.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await _localDb.guardarParticipantes(participantesRemotos);
          } catch (e) {
            print('⚠️ Error guardando en cache: $e');
          }
        });
      }
      
      // 4. Usar cache local SOLO si Firebase está vacío
      if (participantesRemotos.isEmpty) {
        print('⚠️ Firebase vacío, intentando cache local...');
        try {
          final locales = await _localDb.getParticipantesLocales();
          print('📱 Cache local: ${locales.length} participantes');
          
          // Verificar que los del cache estén realmente activos
          final localesActivos = locales.where((p) => p.activo).toList();
          print('📱 Cache local activos: ${localesActivos.length} participantes');
          
          return localesActivos;
        } catch (e) {
          print('❌ Error cargando cache: $e');
          return [];
        }
      }
      
      return participantesRemotos;
    });
  }

  // MÉTODO PARA LIMPIAR INACTIVOS DEL CACHE
  Future<void> limpiarInactivosCache() async {
    print('🧹 Ejecutando limpieza de inactivos del cache...');
    
    try {
      // 1. Diagnosticar primero
      final diagnostico = await _localDb.diagnosticarCacheParticipantes();
      
      print('📋 DIAGNÓSTICO PRE-LIMPIEZA:');
      print('   Total: ${diagnostico['total']}');
      print('   Activos: ${diagnostico['activos']}');
      print('   Inactivos: ${diagnostico['inactivos']}');
      
      if (diagnostico['inactivos'] > 0) {
        print('   Participantes inactivos encontrados:');
        for (var inactivo in diagnostico['detalle_inactivos']) {
          print('     ❌ ${inactivo['idInterno']}: ${inactivo['nombre']}');
        }
      }
      
      // 2. Limpiar inactivos
      await _localDb.removerParticipantesInactivos();
      
      // 3. Diagnosticar después
      final diagnosticoPost = await _localDb.diagnosticarCacheParticipantes();
      print('✅ POST-LIMPIEZA - Inactivos restantes: ${diagnosticoPost['inactivos']}');
      
    } catch (e) {
      print('❌ Error en limpieza: $e');
    }
  }

  // MÉTODO PARA FORZAR ACTUALIZACIÓN DESDE FIREBASE
  Future<void> forzarActualizacionDesdeFirebase() async {
    print('🔄 Forzando actualización desde Firebase...');
    
    try {
      final snapshot = await _db
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();
      
      final participantes = snapshot.docs
          .map((doc) => Participante.fromFirestore(doc))
          .where((p) => p.activo)
          .toList();
      
      print('🔥 Firebase trajo ${participantes.length} participantes activos');
      
      if (participantes.isNotEmpty) {
        // Limpiar cache completamente
        await _localDb.clearParticipantesCache();
        
        // Guardar nuevos datos
        await _localDb.guardarParticipantes(participantes);
        
        print('✅ Cache actualizado correctamente');
      }
      
    } catch (e) {
      print('❌ Error forzando actualización: $e');
    }
  }

  // ENVIAR EVALUACIÓN (CON SOPORTE OFFLINE)
  Future<Map<String, dynamic>> enviarEvaluacion({
    required String participanteId,
    required String participanteNombre,
    required String? categoriaId,
    required String? categoriaNombre,
    required Map<String, double> puntajes,
    required Map<String, String> comentarios,
    required double puntajeTotal,
  }) async {
    // Verificar conexión
    final connectivityResult = await Connectivity().checkConnectivity();
    final tieneInternet = connectivityResult != ConnectivityResult.none;
    
    // Datos del juez actual
    final juezId = UserSession.idInterno ?? '';
    final juezNombre = UserSession.displayName;
    
    if (tieneInternet) {
      // ✅ HAY INTERNET - Enviar directamente
      try {
        await _db.collection(collectionEvaluaciones).add({
          'juezId': juezId,
          'juezNombre': juezNombre,
          'juezCodigo': UserSession.cod,
          'participanteId': participanteId,
          'participanteNombre': participanteNombre,
          'categoriaId': categoriaId,
          'categoriaNombre': categoriaNombre,
          'puntajes': puntajes,
          'comentarios': comentarios,
          'puntajeTotal': puntajeTotal,
          'timestamp': FieldValue.serverTimestamp(),
          'isFinal': true,
          'dispositivo': 'App Certamen',
          'syncFromLocal': false,
        });
        
        print('✅ Evaluación enviada a Firebase');
        
        return {
          'success': true,
          'message': 'Evaluación enviada exitosamente',
          'wasOffline': false,
        };
        
      } catch (e) {
        print('❌ Error enviando a Firebase: $e');
        
        // Si falla, guardar localmente igual
        return await _guardarEvaluacionLocal(
          juezId: juezId,
          juezNombre: juezNombre,
          participanteId: participanteId,
          participanteNombre: participanteNombre,
          categoriaId: categoriaId,
          categoriaNombre: categoriaNombre,
          puntajes: puntajes,
          comentarios: comentarios,
          puntajeTotal: puntajeTotal,
          errorOriginal: e.toString(),
        );
      }
      
    } else {
      // ❌ NO HAY INTERNET - Guardar localmente
      return await _guardarEvaluacionLocal(
        juezId: juezId,
        juezNombre: juezNombre,
        participanteId: participanteId,
        participanteNombre: participanteNombre,
        categoriaId: categoriaId,
        categoriaNombre: categoriaNombre,
        puntajes: puntajes,
        comentarios: comentarios,
        puntajeTotal: puntajeTotal,
        errorOriginal: 'Sin conexión a internet',
      );
    }
  }

  Future<Map<String, dynamic>> _guardarEvaluacionLocal({
    required String juezId,
    required String juezNombre,
    required String participanteId,
    required String participanteNombre,
    required String? categoriaId,
    required String? categoriaNombre,
    required Map<String, double> puntajes,
    required Map<String, String> comentarios,
    required double puntajeTotal,
    String? errorOriginal,
  }) async {
    try {
      final evaluacionId = await _localDb.guardarEvaluacionPendiente(
        juezId: juezId,
        juezNombre: juezNombre,
        participanteId: participanteId,
        participanteNombre: participanteNombre,
        categoriaId: categoriaId,
        categoriaNombre: categoriaNombre,
        puntajes: puntajes,
        comentarios: comentarios,
        puntajeTotal: puntajeTotal,
      );
      
      print('💾 Evaluación guardada localmente: $evaluacionId');
      
      // Iniciar monitoreo para cuando regrese el internet
      _syncService.startMonitoring();
      
      return {
        'success': true,
        'message': 'Evaluación guardada localmente. Se enviará automáticamente cuando haya internet.',
        'wasOffline': true,
        'localId': evaluacionId,
        'warning': errorOriginal != null ? 'Error original: $errorOriginal' : null,
      };
      
    } catch (e) {
      print('❌❌ ERROR CRÍTICO: No se pudo guardar ni localmente: $e');
      
      return {
        'success': false,
        'message': 'Error crítico. No se pudo guardar la evaluación. Intenta nuevamente.',
        'wasOffline': true,
        'error': e.toString(),
      };
    }
  }

  // Verificar si ya evaluó (CONSIDERANDO EVALUACIONES PENDIENTES)
  Future<bool> yaEvaluada(String participanteId, String juezId) async {
    try {
      // 1. Primero verificar en Firebase
      final snapshotFirebase = await _db
          .collection(collectionEvaluaciones)
          .where('participanteId', isEqualTo: participanteId)
          .where('juezId', isEqualTo: juezId)
          .limit(1)
          .get();

      if (snapshotFirebase.docs.isNotEmpty) {
        return true;
      }
      
      // 2. Verificar en evaluaciones pendientes locales
      final pendientes = await _localDb.getEvaluacionesPendientes();
      final evaluacionPendiente = pendientes.firstWhere(
        (e) => e['participanteId'] == participanteId && e['juezId'] == juezId,
        orElse: () => {},
      );
      
      return evaluacionPendiente.isNotEmpty;
      
    } catch (e) {
      print('❌ Error verificando evaluación: $e');
      return false;
    }
  }

  // Obtener estado de evaluación (incluyendo pendientes)
  Future<Map<String, bool>> getEstadosEvaluacion(
      List<Participante> participantes, String juezId) async {
    final estados = <String, bool>{};

    for (final participante in participantes) {
      final evaluada = await yaEvaluada(participante.id, juezId);
      estados[participante.id] = evaluada;
    }

    return estados;
  }

  // Obtener estadísticas de sync
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _syncService.getSyncStatus();
  }

  // MÉTODO DE DIAGNÓSTICO COMPLETO
  Future<void> diagnosticarProblema() async {
    print('==========================================');
    print('🔍 DIAGNÓSTICO COMPLETO DEL PROBLEMA');
    print('==========================================');
    
    try {
      // 1. Verificar Firebase directamente
      print('\n1. 📡 CONSULTA DIRECTA A FIREBASE:');
      final firebaseSnapshot = await _db
          .collection(collectionParticipantes)
          .get();
      
      print('   Total en Firebase: ${firebaseSnapshot.docs.length}');
      
      for (var doc in firebaseSnapshot.docs) {
        final data = doc.data();
        print('   👤 ${data['idInterno']}: ${data['nombre']}');
        print('      activo: ${data['activo']} (${data['activo'].runtimeType})');
      }
      
      // 2. Verificar query con filtro
      print('\n2. 🔎 QUERY CON FILTRO activo=true:');
      final filteredSnapshot = await _db
          .collection(collectionParticipantes)
          .where('activo', isEqualTo: true)
          .get();
      
      print('   Con filtro activo=true: ${filteredSnapshot.docs.length}');
      
      // 3. Verificar cache local
      print('\n3. 💾 CACHE LOCAL:');
      final cacheDiagnostico = await _localDb.diagnosticarCacheParticipantes();
      print('   Total en cache: ${cacheDiagnostico['total']}');
      print('   Activos en cache: ${cacheDiagnostico['activos']}');
      print('   Inactivos en cache: ${cacheDiagnostico['inactivos']}');
      
      if (cacheDiagnostico['inactivos'] > 0) {
        print('   ⚠️ PROBLEMA DETECTADO: Hay inactivos en cache!');
      }
      
      print('\n==========================================');
      print('🎯 CONCLUSIÓN:');
      
      if (firebaseSnapshot.docs.length == filteredSnapshot.docs.length) {
        print('✅ Firebase filtra correctamente');
        
        if (cacheDiagnostico['inactivos'] > 0) {
          print('❌ El problema está en el CACHE LOCAL');
          print('   Solución: Ejecutar "limpiarInactivosCache()"');
        } else {
          print('✅ Todo funciona correctamente');
        }
      } else {
        print('❌ Firebase NO está filtrando correctamente');
        print('   Revisa índices o tipo de datos');
      }
      
    } catch (e) {
      print('❌ Error en diagnóstico: $e');
    }
    
    print('==========================================');
  }
}