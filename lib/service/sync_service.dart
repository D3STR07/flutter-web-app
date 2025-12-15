import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/participante_model.dart';
import './calificacion_local_service.dart';
import './calificacion_service.dart';
import './local_database.dart';
import './auth_service.dart';
import './user_session.dart';

class SyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalDatabase _localDb = LocalDatabase();
  final CalificacionLocalService _calificacionLocalService = CalificacionLocalService();
  final CalificacionService _calificacionService = CalificacionService();
  
  StreamSubscription? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;

  // INICIAR MONITOREO DE CONEXIÓN
  void startMonitoring() {
    print('🔄 SyncService iniciado');
    
    // Monitorear cambios en la conexión
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      print('🌐 Estado de conexión cambiado: $result');
      
      if (result != ConnectivityResult.none) {
        // ¡HAY INTERNET! Intentar sincronizar
        _intentarSincronizarTodo();
      }
    });

    // Sincronizar cada 30 segundos si hay internet
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _intentarSincronizarTodo();
    });

    // También sincronizar cuando la app vuelve al frente
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        onResume: () => _intentarSincronizarTodo(),
      ),
    );
  }

  // DETENER MONITOREO
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }

  // VERIFICAR CONEXIÓN
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  // INTENTAR SINCRONIZAR TODO
  Future<void> _intentarSincronizarTodo() async {
    if (_isSyncing) return;
    
    final tieneInternet = await hasInternetConnection();
    if (!tieneInternet) {
      print('📡 Sin conexión a internet');
      return;
    }
    
    _isSyncing = true;
    print('🔄 Iniciando sincronización completa...');
    
    try {
      // 1. Sincronizar calificaciones pendientes
      await _syncCalificacionesPendientes();
      
      // 2. Sincronizar evaluaciones pendientes (si tienes)
      await _syncEvaluacionesPendientes();
      
      print('✅ Sincronización completada');
    } catch (e) {
      print('❌ Error en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // SINCRONIZAR CALIFICACIONES PENDIENTES
  Future<void> _syncCalificacionesPendientes() async {
    try {
      // Obtener calificaciones pendientes
      final pendientes = await _calificacionLocalService.getCalificacionesPendientes();
      
      if (pendientes.isEmpty) {
        print('✅ No hay calificaciones pendientes para sincronizar');
        return;
      }
      
      print('🔄 Sincronizando ${pendientes.length} calificaciones pendientes...');
      
      // Sincronizar cada una
      for (final calificacion in pendientes) {
        try {
          // Subir a Firebase
          await _calificacionService.guardarCalificacionFirebase(calificacion);
          
          // Marcar como sincronizada localmente
          await _calificacionLocalService.marcarComoSincronizada(calificacion.id);
          
          print('   ✅ Sincronizada: ${calificacion.criterioId}');
        } catch (e) {
          print('   ❌ Error sincronizando ${calificacion.id}: $e');
          // Continuar con las siguientes aunque falle una
        }
      }
      
      print('🎉 Calificaciones sincronizadas: ${pendientes.length}');
      
    } catch (e) {
      print('❌ Error sincronizando calificaciones: $e');
    }
  }

  // SINCRONIZAR EVALUACIONES PENDIENTES (si tienes este sistema)
  Future<void> _syncEvaluacionesPendientes() async {
    try {
      final tienePendientes = await _localDb.tieneEvaluacionesPendientes();
      if (!tienePendientes) return;
      
      final pendientes = await _localDb.getEvaluacionesPendientes();
      
      print('🔄 Sincronizando ${pendientes.length} evaluaciones pendientes...');
      
      for (final evaluacion in pendientes) {
        await _enviarEvaluacionAFirebase(evaluacion);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
    } catch (e) {
      print('❌ Error sincronizando evaluaciones: $e');
    }
  }

  // ENVIAR UNA EVALUACIÓN A FIREBASE (si usas este sistema)
  Future<void> _enviarEvaluacionAFirebase(Map<String, dynamic> evaluacion) async {
    try {
      print('📤 Enviando evaluación: ${evaluacion['id']}');
      
      await _db.collection('evaluaciones').add({
        'juezId': evaluacion['juezId'],
        'juezNombre': evaluacion['juezNombre'],
        'juezCodigo': UserSession.cod,
        'participanteId': evaluacion['participanteId'],
        'participanteNombre': evaluacion['participanteNombre'],
        'categoriaId': evaluacion['categoriaId'],
        'categoriaNombre': evaluacion['categoriaNombre'],
        'puntajes': evaluacion['puntajes'],
        'comentarios': evaluacion['comentarios'],
        'puntajeTotal': evaluacion['puntajeTotal'],
        'timestamp': FieldValue.serverTimestamp(),
        'isFinal': true,
        'dispositivo': 'App Certamen',
        'syncFromLocal': true,
        'originalLocalId': evaluacion['id'],
      });

      // MARCAR COMO ENVIADA EN LOCAL
      await _localDb.marcarEvaluacionEnviada(evaluacion['id']);
      
      print('✅ Evaluación ${evaluacion['id']} enviada exitosamente');
      
    } catch (e) {
      print('❌ Error enviando evaluación ${evaluacion['id']}: $e');
      await _localDb.aumentarIntentoEnvio(evaluacion['id'], e.toString());
    }
  }

  // CARGAR Y GUARDAR CACHE DE PARTICIPANTES
  Future<void> cargarCacheParticipantes() async {
    try {
      final tieneInternet = await hasInternetConnection();
      
      if (tieneInternet) {
        // Cargar desde Firebase y guardar en local
        final snapshot = await _db
            .collection('participantes')
            .where('activo', isEqualTo: true)
            .get();
        
        final participantes = snapshot.docs.map((doc) {
          final data = doc.data();
          return Participante(
            id: doc.id,
            idInterno: data['idInterno'] ?? '',
            nombre: data['nombre'] ?? '',
            fotoUrl: data['fotoUrl'],
            activo: data['activo'] ?? true,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          );
        }).toList();
        
        await _localDb.guardarParticipantes(participantes);
        print('💾 Cache de participantes actualizado');
      }
      
    } catch (e) {
      print('❌ Error cargando cache: $e');
    }
  }

  // FORZAR SINCRONIZACIÓN MANUAL
  Future<void> forceSync() async {
    print('🔄 Forzando sincronización manual...');
    await _intentarSincronizarTodo();
  }

  // SINCRONIZACIÓN MANUAL (desde UI)
  Future<void> syncNow() async {
    await _intentarSincronizarTodo();
  }

  // OBTENER ESTADO DE SINCRONIZACIÓN
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final pendientesCalificaciones = await _calificacionLocalService.getCalificacionesPendientes();
      final tieneInternet = await hasInternetConnection();
      final pendientesCount = pendientesCalificaciones.length;
      
      return {
        'tieneInternet': tieneInternet,
        'pendientesCount': pendientesCount,
        'isSyncing': _isSyncing,
        'pendientes': pendientesCalificaciones.map((c) => {
          'id': c.id,
          'etapa': c.etapaId,
          'criterio': c.criterioId,
          'puntaje': c.puntaje,
          'isSynced': c.isSynced,
        }).toList(),
      };
    } catch (e) {
      return {
        'tieneInternet': false,
        'pendientesCount': 0,
        'isSyncing': false,
        'pendientes': [],
      };
    }
  }

  // OBTENER CONTEO DE PENDIENTES
  Future<int> getConteoPendientes() async {
    try {
      final pendientes = await _calificacionLocalService.getCalificacionesPendientes();
      return pendientes.length;
    } catch (e) {
      return 0;
    }
  }
}

// Observer para ciclo de vida de la app
class LifecycleEventHandler extends WidgetsBindingObserver {
  final VoidCallback onResume;
  
  LifecycleEventHandler({required this.onResume});
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App reanudada - sincronizando...');
        onResume();
        break;
      case AppLifecycleState.paused:
        print('📱 App en pausa');
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
}