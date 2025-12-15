import 'package:sqflite/sqflite.dart';
import '../data/models/etapa_model.dart';
import '../utils/helpers/database_helper.dart';

class EtapaLocalSource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Obtener todas las etapas
  Future<List<Etapa>> getEtapas() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'etapas',
      orderBy: 'order ASC', // CAMBIADO de 'order' a 'etapaOrder'
    );
    
    return maps.map((map) => Etapa.fromMap(map)).toList();
  }

  // Obtener etapa por ID
  Future<Etapa?> getEtapaById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'etapas',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Etapa.fromMap(maps.first);
    }
    return null;
  }

  // Obtener etapa activa
  Future<Etapa?> getEtapaActiva() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'etapas',
      where: 'status = ?',
      whereArgs: ['active'],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Etapa.fromMap(maps.first);
    }
    return null;
  }

  // Guardar etapa
  Future<void> saveEtapa(Etapa etapa) async {
    final db = await _dbHelper.database;
    await db.insert(
      'etapas',
      etapa.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Si no está sincronizada, agregar a cola de sincronización
    if (!etapa.isSynced) {
      await _addToSyncQueue('INSERT', 'etapas', etapa);
    }
  }

  // Actualizar etapa
  Future<void> updateEtapa(Etapa etapa) async {
    final db = await _dbHelper.database;
    final updatedEtapa = etapa.copyWith(
      lastUpdated: DateTime.now(),
      isSynced: etapa.isSynced, // Mantener estado de sincronización
    );
    
    await db.update(
      'etapas',
      updatedEtapa.toMap(),
      where: 'id = ?',
      whereArgs: [etapa.id],
    );

    // Agregar a cola de sincronización
    await _addToSyncQueue('UPDATE', 'etapas', updatedEtapa);
  }

  // Eliminar etapa
  Future<void> deleteEtapa(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'etapas',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Agregar a cola de sincronización
    final etapa = await getEtapaById(id);
    if (etapa != null) {
      await _addToSyncQueue('DELETE', 'etapas', etapa);
    }
  }

  // Guardar múltiples etapas
  Future<void> saveEtapas(List<Etapa> etapas) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      for (final etapa in etapas) {
        await txn.insert(
          'etapas',
          etapa.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Buscar etapas no sincronizadas
  Future<List<Etapa>> getUnsyncedEtapas() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'etapas',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    
    return maps.map((map) => Etapa.fromMap(map)).toList();
  }

  // Marcar como sincronizado
  Future<void> markAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'etapas',
      {'isSynced': 1, 'lastUpdated': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Limpiar etapas (para sincronización completa)
  Future<void> clearEtapas() async {
    final db = await _dbHelper.database;
    await db.delete('etapas');
  }

  // Métodos privados para sincronización
  Future<void> _addToSyncQueue(String operation, String table, Etapa etapa) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'operation': operation,
      'table_name': table,
      'data': _etapaToJson(etapa),
      'createdAt': DateTime.now().toIso8601String(),
      'attempts': 0,
      'lastAttempt': null,
    });
  }

  String _etapaToJson(Etapa etapa) {
    return '''
    {
      "id": "${etapa.id}",
      "name": "${etapa.name}",
      "color": "${etapa.color}",
      "etapa_order": ${etapa.order}, // CAMBIADO de "order" a "etapa_order"
      "status": "${etapa.status}",
      "type": "${etapa.type}"
    }
    ''';
  }

  // Verificar si hay conexión (para simular)
  Future<bool> hasConnection() async {
    // En una app real, aquí verificarías la conectividad
    return true; // Cambiar por lógica real de conectividad
  }

  // Método faltante para obtener todas las etapas como Future
  Future<List<Etapa>> getEtapasList() async {
    return getEtapas();
  }
}