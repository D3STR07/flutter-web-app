import 'etapa_repository.dart';
import 'etapa_local_source.dart';
import 'etapa_remote_source.dart';
import '../data/models/etapa_model.dart';
import './user_session.dart';

class EtapaService {
  final EtapaRepository _repository;
  
  // Singleton
  static final EtapaService _instance = EtapaService._internal();
  factory EtapaService() => _instance;
  
  // Constructor privado que inicializa TODO automáticamente
  EtapaService._internal() 
    : _repository = EtapaRepository(
        localSource: EtapaLocalSource(),
        remoteSource: EtapaRemoteSource(),
      );
  
  // Siempre está inicializado
  bool get isInitialized => true;

  // Obtener todas las etapas
  Stream<List<Etapa>> getEtapas() {
    return _repository.getEtapas();
  }

  // Obtener etapa activa
  Stream<Etapa?> getEtapaActiva() {
    return _repository.getEtapaActiva();
  }

  // Activar una etapa (solo admin)
  Future<bool> activarEtapa(String etapaId) async {
    if (!UserSession.isAdmin) {
      print('❌ Solo administradores pueden activar etapas');
      return false;
    }

    try {
      return await _repository.activarEtapa(etapaId);
    } catch (e) {
      print('❌ Error activando etapa: $e');
      rethrow;
    }
  }

  // Finalizar etapa activa
  Future<bool> finalizarEtapaActiva() async {
    if (!UserSession.isAdmin) return false;

    try {
      return await _repository.finalizarEtapaActiva();
    } catch (e) {
      print('❌ Error finalizando etapa: $e');
      rethrow;
    }
  }

  // Reabrir etapa finalizada
  Future<bool> reabrirEtapa(String etapaId) async {
    if (!UserSession.isAdmin) return false;

    try {
      final etapa = await getEtapaById(etapaId);
      if (etapa == null) return false;

      final etapaActualizada = etapa.copyWith(
        status: 'closed',
        fechaFin: null,
        isSynced: false,
        lastUpdated: DateTime.now(),
      );

      await _repository.updateEtapa(etapaActualizada);
      return true;
    } catch (e) {
      print('❌ Error reabriendo etapa: $e');
      return false;
    }
  }

  // Obtener etapa por ID
  Future<Etapa?> getEtapaById(String etapaId) async {
    // Necesitamos obtener de la lista actual
    try {
      final etapas = await _repository.getEtapas().first;
      return etapas.firstWhere((etapa) => etapa.id == etapaId);
    } catch (e) {
      return null;
    }
  }

  // Sincronizar manualmente
  Future<void> sync() async {
    await _repository.sync();
  }

  // Verificar si hay etapa activa
  Future<bool> hayEtapaActiva() async {
    final etapaActiva = await _repository.getEtapaActiva().first;
    return etapaActiva != null;
  }

  // Verificar permisos para acceder a etapa
  bool puedeAccederAEtapa(Etapa etapa) {
    if (UserSession.isAdmin) return true;
    if (UserSession.isJudge) return etapa.esAccesibleParaJueces;
    return false;
  }

  // Verificar si hay datos locales
  Future<bool> hasLocalData() async {
    return await _repository.hasLocalData();
  }

  // Limpiar caché
  Future<void> clearCache() async {
    await _repository.clearCache();
  }
}