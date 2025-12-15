import 'dart:async';
import '../data/models/etapa_model.dart';
import 'etapa_local_source.dart';
import 'etapa_remote_source.dart';

class EtapaRepository {
  final EtapaLocalSource _localSource;
  final EtapaRemoteSource _remoteSource;
  
  bool _isSyncing = false;
  final StreamController<List<Etapa>> _etapasStreamController = 
      StreamController<List<Etapa>>.broadcast();
  final StreamController<Etapa?> _etapaActivaStreamController = 
      StreamController<Etapa?>.broadcast();

  EtapaRepository({
    required EtapaLocalSource localSource,
    required EtapaRemoteSource remoteSource,
  }) : _localSource = localSource, _remoteSource = remoteSource {
    // Iniciar sincronización automática
    _startAutoSync();
  }

  // Obtener todas las etapas (local primero, luego sincroniza)
  Stream<List<Etapa>> getEtapas() {
    // Emitir datos locales inmediatamente
    _emitLocalEtapas();
    
    // Escuchar cambios en Firebase
    _remoteSource.getEtapasStream().listen((remoteEtapas) {
      // Guardar localmente
      _saveEtapasLocally(remoteEtapas);
      // Emitir
      _etapasStreamController.add(remoteEtapas);
    }, onError: (error) {
      // En caso de error, emitir datos locales
      _emitLocalEtapas();
    });

    return _etapasStreamController.stream;
  }

  // Obtener etapa activa
  Stream<Etapa?> getEtapaActiva() {
    // Emitir local inmediatamente
    _emitLocalEtapaActiva();
    
    // Escuchar cambios en Firebase
    _remoteSource.getEtapaActivaStream().listen((etapaActiva) {
      // Emitir
      _etapaActivaStreamController.add(etapaActiva);
    }, onError: (error) {
      // En caso de error, emitir local
      _emitLocalEtapaActiva();
    });

    return _etapaActivaStreamController.stream;
  }

  // Guardar etapa (offline-first)
  Future<String> saveEtapa(Etapa etapa) async {
    // Guardar localmente primero
    final etapaLocal = etapa.copyWith(
      isSynced: false,
      lastUpdated: DateTime.now(),
    );
    
    await _localSource.saveEtapa(etapaLocal);
    
    // Intentar sincronizar inmediatamente
    await _syncEtapa(etapaLocal);
    
    // Emitir cambios
    _emitLocalEtapas();
    
    return etapaLocal.id;
  }

  // Actualizar etapa
  Future<void> updateEtapa(Etapa etapa) async {
    // Actualizar local primero
    final etapaLocal = etapa.copyWith(
      isSynced: false,
      lastUpdated: DateTime.now(),
    );
    
    await _localSource.updateEtapa(etapaLocal);
    
    // Intentar sincronizar
    await _syncEtapa(etapaLocal);
    
    // Emitir cambios
    _emitLocalEtapas();
  }

  // Activar etapa
  Future<bool> activarEtapa(String etapaId) async {
    try {
      // Verificar si hay conexión
      final hasConnection = await _remoteSource.hasConnection();
      
      if (hasConnection) {
        // Si hay conexión, hacer en Firebase directamente
        final userId = _remoteSource.getCurrentUserId();
        final userName = _remoteSource.getCurrentUserName();
        
        if (userId == null || userName == null) {
          throw Exception('Usuario no autenticado');
        }
        
        final success = await _remoteSource.activarEtapa(
          etapaId, 
          userId, 
          userName
        );
        
        if (success) {
          // Actualizar localmente después del éxito
          await _syncWithRemote();
        }
        
        return success;
      } else {
        // Sin conexión, guardar localmente como pendiente
        final etapa = await _localSource.getEtapaById(etapaId);
        if (etapa != null) {
          final etapaActualizada = etapa.copyWith(
            status: 'active',
            fechaInicio: DateTime.now(),
            isSynced: false,
            lastUpdated: DateTime.now(),
          );
          
          await _localSource.updateEtapa(etapaActualizada);
          _emitLocalEtapas();
          
          // Agregar a cola para sincronizar cuando haya conexión
          await _syncEtapa(etapaActualizada);
        }
        return true; // Devuelve éxito local
      }
    } catch (e) {
      print('Error activando etapa: $e');
      rethrow;
    }
  }

  // Finalizar etapa activa
  Future<bool> finalizarEtapaActiva() async {
    try {
      final hasConnection = await _remoteSource.hasConnection();
      
      if (hasConnection) {
        final userId = _remoteSource.getCurrentUserId();
        final userName = _remoteSource.getCurrentUserName();
        
        if (userId == null || userName == null) {
          throw Exception('Usuario no autenticado');
        }
        
        final success = await _remoteSource.finalizarEtapaActiva(
          userId, 
          userName
        );
        
        if (success) {
          await _syncWithRemote();
        }
        
        return success;
      } else {
        // Sin conexión, buscar etapa activa localmente y finalizarla
        final etapaActiva = await _localSource.getEtapaActiva();
        if (etapaActiva != null) {
          final etapaFinalizada = etapaActiva.copyWith(
            status: 'finished',
            fechaFin: DateTime.now(),
            isSynced: false,
            lastUpdated: DateTime.now(),
          );
          
          await _localSource.updateEtapa(etapaFinalizada);
          _emitLocalEtapas();
          
          await _syncEtapa(etapaFinalizada);
        }
        return true;
      }
    } catch (e) {
      print('Error finalizando etapa: $e');
      rethrow;
    }
  }

  // Eliminar etapa
  Future<void> deleteEtapa(String etapaId) async {
    // Marcar como eliminado localmente
    await _localSource.deleteEtapa(etapaId);
    
    // Intentar eliminar en remoto
    final hasConnection = await _remoteSource.hasConnection();
    if (hasConnection) {
      try {
        await _remoteSource.deleteEtapa(etapaId);
      } catch (e) {
        print('Error eliminando en remoto, quedará en cola: $e');
      }
    }
    
    _emitLocalEtapas();
  }

  // Sincronizar manualmente
  Future<void> sync() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    try {
      // 1. Descargar datos remotos
      final remoteEtapas = await _remoteSource.getEtapas();
      
      // 2. Guardar localmente
      await _saveEtapasLocally(remoteEtapas);
      
      // 3. Subir cambios locales pendientes
      await _syncPendingChanges();
      
      // 4. Emitir cambios
      _emitLocalEtapas();
      
    } catch (e) {
      print('Error en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Métodos privados de ayuda
  Future<void> _saveEtapasLocally(List<Etapa> etapas) async {
    try {
      await _localSource.saveEtapas(etapas);
    } catch (e) {
      print('Error guardando etapas localmente: $e');
      // Continuar incluso si hay error al guardar localmente
    }
  }

  Future<void> _syncEtapa(Etapa etapa) async {
    final hasConnection = await _remoteSource.hasConnection();
    
    if (hasConnection && !etapa.isSynced) {
      try {
        await _remoteSource.saveEtapa(etapa);
        await _localSource.markAsSynced(etapa.id);
      } catch (e) {
        print('Error sincronizando etapa ${etapa.id}: $e');
      }
    }
  }

  Future<void> _syncPendingChanges() async {
    final unsyncedEtapas = await _localSource.getUnsyncedEtapas();
    
    for (final etapa in unsyncedEtapas) {
      await _syncEtapa(etapa);
    }
  }

  Future<void> _syncWithRemote() async {
    try {
      final remoteEtapas = await _remoteSource.getEtapas();
      await _saveEtapasLocally(remoteEtapas);
    } catch (e) {
      print('Error sincronizando con remoto: $e');
    }
  }

  void _emitLocalEtapas() async {
    try {
      final etapas = await _localSource.getEtapas();
      _etapasStreamController.add(etapas);
    } catch (e) {
      print('Error emitiendo etapas locales: $e');
    }
  }

  void _emitLocalEtapaActiva() async {
    try {
      final etapaActiva = await _localSource.getEtapaActiva();
      _etapaActivaStreamController.add(etapaActiva);
    } catch (e) {
      print('Error emitiendo etapa activa local: $e');
    }
  }

  void _startAutoSync() {
    // Sincronizar cada 30 segundos si hay conexión
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final hasConnection = await _remoteSource.hasConnection();
      if (hasConnection && !_isSyncing) {
        await _syncPendingChanges();
        await _syncWithRemote();
      }
    });
  }

  // Limpiar caché
  Future<void> clearCache() async {
    await _localSource.clearEtapas();
    _etapasStreamController.add([]);
    _etapaActivaStreamController.add(null);
  }

  // Verificar si hay datos locales
  Future<bool> hasLocalData() async {
    try {
      final etapas = await _localSource.getEtapas();
      return etapas.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Cerrar streams
  void dispose() {
    _etapasStreamController.close();
    _etapaActivaStreamController.close();
  }
}