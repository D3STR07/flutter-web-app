import 'package:reina_nochebuena/data/models/calificacion_model.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/models/calificacion_model.dart';

class CalificacionDao {
  final Database db;

  CalificacionDao(this.db);

  // Crear tabla
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calificaciones (
        id TEXT PRIMARY KEY,
        juezId TEXT NOT NULL,
        participanteId TEXT NOT NULL,
        etapaId TEXT NOT NULL,
        criterioId TEXT NOT NULL,
        puntaje REAL NOT NULL,
        comentario TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0,
        fecha TEXT NOT NULL,
        fechaSync TEXT,
        UNIQUE(juezId, participanteId, etapaId, criterioId)
      )
    ''');
    
    // Índices para búsquedas rápidas
    await db.execute('CREATE INDEX IF NOT EXISTS idx_juez ON calificaciones(juezId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_synced ON calificaciones(isSynced)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_etapa ON calificaciones(etapaId, participanteId)');
  }

  // Guardar calificación
  Future<void> saveCalificacion(Calificacion calificacion) async {
    await db.insert(
      'calificaciones',
      calificacion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener calificaciones no sincronizadas
  Future<List<Calificacion>> getUnsyncedCalificaciones() async {
    final maps = await db.query(
      'calificaciones',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    
    return maps.map((map) => Calificacion.fromMap(map)).toList();
  }

  // Obtener calificaciones por juez y participante
  Future<List<Calificacion>> getCalificacionesByJuezParticipante({
    required String juezId,
    required String participanteId,
    String? etapaId,
  }) async {
    String where = 'juezId = ? AND participanteId = ?';
    List<dynamic> whereArgs = [juezId, participanteId];
    
    if (etapaId != null) {
      where += ' AND etapaId = ?';
      whereArgs.add(etapaId);
    }
    
    final maps = await db.query(
      'calificaciones',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'etapaId, criterioId',
    );
    
    return maps.map((map) => Calificacion.fromMap(map)).toList();
  }

  // Verificar si criterio ya fue calificado
  Future<bool> isCriterioCalificado({
    required String juezId,
    required String participanteId,
    required String etapaId,
    required String criterioId,
  }) async {
    final maps = await db.query(
      'calificaciones',
      where: 'juezId = ? AND participanteId = ? AND etapaId = ? AND criterioId = ?',
      whereArgs: [juezId, participanteId, etapaId, criterioId],
      limit: 1,
    );
    
    return maps.isNotEmpty;
  }

  // Marcar como sincronizado
  Future<void> markAsSynced(String calificacionId) async {
    await db.update(
      'calificaciones',
      {
        'isSynced': 1,
        'fechaSync': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [calificacionId],
    );
  }

  // Eliminar calificación
  Future<void> deleteCalificacion(String calificacionId) async {
    await db.delete(
      'calificaciones',
      where: 'id = ?',
      whereArgs: [calificacionId],
    );
  }

  // Obtener total de calificaciones pendientes
  Future<int> getPendingCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM calificaciones WHERE isSynced = 0'
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Limpiar todas las calificaciones (solo para debug)
  Future<void> clearAll() async {
    await db.delete('calificaciones');
  }
}