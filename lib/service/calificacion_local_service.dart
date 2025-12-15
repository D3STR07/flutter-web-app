import 'package:reina_nochebuena/data/local_db/calificacion_dao.dart';

import '../data/models/calificacion_model.dart';
import '../utils/helpers/database_helper.dart';
import 'user_session.dart';

class CalificacionLocalService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  CalificacionDao? _calificacionDao;

  Future<CalificacionDao> get _dao async {
    if (_calificacionDao == null) {
      await _dbHelper.initCalificacionesTables();
      _calificacionDao = _dbHelper.calificacionDao;
    }
    return _calificacionDao!;
  }

  // Guardar calificación localmente (offline-first)
  Future<void> guardarCalificacionLocal(Calificacion calificacion) async {
    print('💾 Guardando LOCALMENTE: ${calificacion.criterioId} = ${calificacion.puntaje}');
    
    final dao = await _dao;
    await dao.saveCalificacion(calificacion);
    
    print('✅ Guardado localmente (ID: ${calificacion.id})');
  }

  // Obtener calificaciones del juez actual para un participante
  Future<List<Calificacion>> getCalificacionesLocales({
    required String participanteId,
    String? etapaId,
  }) async {
    final dao = await _dao;
    
    return await dao.getCalificacionesByJuezParticipante(
      juezId: UserSession.firebaseId!,
      participanteId: participanteId,
      etapaId: etapaId,
    );
  }

  // Verificar si ya calificó un criterio (localmente)
  Future<bool> criterioYaCalificadoLocal({
    required String participanteId,
    required String etapaId,
    required String criterioId,
  }) async {
    final dao = await _dao;
    
    return await dao.isCriterioCalificado(
      juezId: UserSession.firebaseId!,
      participanteId: participanteId,
      etapaId: etapaId,
      criterioId: criterioId,
    );
  }

  // Obtener calificaciones pendientes de sincronizar
  Future<List<Calificacion>> getCalificacionesPendientes() async {
    final dao = await _dao;
    return await dao.getUnsyncedCalificaciones();
  }

  // Marcar calificación como sincronizada
  Future<void> marcarComoSincronizada(String calificacionId) async {
    final dao = await _dao;
    await dao.markAsSynced(calificacionId);
  }

  // Obtener conteo de pendientes
  Future<int> getConteoPendientes() async {
    final dao = await _dao;
    return await dao.getPendingCount();
  }

  // Eliminar calificación local
  Future<void> eliminarCalificacionLocal(String calificacionId) async {
    final dao = await _dao;
    await dao.deleteCalificacion(calificacionId);
  }

  // Verificar si etapa está completamente calificada
  Future<bool> etapaCompletamenteCalificada({
    required String participanteId,
    required String etapaId,
    required int totalCriterios,
  }) async {
    final calificaciones = await getCalificacionesLocales(
      participanteId: participanteId,
      etapaId: etapaId,
    );
    
    return calificaciones.length >= totalCriterios;
  }
}