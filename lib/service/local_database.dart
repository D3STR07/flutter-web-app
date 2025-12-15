import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/models/participante_model.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'certamen_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla para participantes (cache local)
        await db.execute('''
          CREATE TABLE participantes(
            id TEXT PRIMARY KEY,
            idInterno TEXT,
            nombre TEXT NOT NULL,
            fotoUrl TEXT,
            activo INTEGER DEFAULT 1,
            createdAt TEXT,
            syncStatus INTEGER DEFAULT 0
          )
        ''');

        // Tabla para evaluaciones PENDIENTES de enviar
        await db.execute('''
          CREATE TABLE evaluaciones_pendientes(
            id TEXT PRIMARY KEY,
            juezId TEXT NOT NULL,
            juezNombre TEXT,
            participanteId TEXT NOT NULL,
            participanteNombre TEXT,
            categoriaId TEXT,
            categoriaNombre TEXT,
            puntajes TEXT, -- JSON como texto
            comentarios TEXT, -- JSON como texto
            puntajeTotal REAL,
            timestamp TEXT,
            intentosEnvio INTEGER DEFAULT 0,
            ultimoIntento TEXT,
            estado TEXT DEFAULT 'pendiente' -- pendiente, enviando, error, exitoso
          )
        ''');

        // Tabla para logs de operaciones
        await db.execute('''
          CREATE TABLE logs_sync(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accion TEXT,
            datos TEXT,
            timestamp TEXT,
            exito INTEGER DEFAULT 0,
            error TEXT
          )
        ''');
      },
    );
  }

  // ============ MÉTODOS PARA PARTICIPANTES ============

  // GUARDAR PARTICIPANTES LOCALMENTE - SOLO ACTIVOS
  Future<void> guardarParticipantes(List<Participante> participantes) async {
    final db = await database;
    
    // FILTRAR: Solo guardar participantes ACTIVOS
    final participantesActivos = participantes.where((p) => p.activo).toList();
    
    if (participantesActivos.isEmpty) {
      print('⚠️ No hay participantes activos para guardar en cache');
      return;
    }
    
    final batch = db.batch();
    
    for (final participante in participantesActivos) {
      batch.insert(
        'participantes',
        {
          'id': participante.id,
          'idInterno': participante.idInterno,
          'nombre': participante.nombre,
          'fotoUrl': participante.fotoUrl,
          'activo': 1, // Siempre 1 porque ya filtramos
          'createdAt': participante.createdAt?.toIso8601String(),
          'syncStatus': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    print('💾 ${participantesActivos.length} participantes ACTIVOS guardados localmente');
  }

  // OBTENER PARTICIPANTES DESDE CACHE - SOLO ACTIVOS
  Future<List<Participante>> getParticipantesLocales() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'participantes',
      where: 'activo = 1',
      orderBy: 'nombre',
    );

    print('📱 Cache local: ${maps.length} participantes activos');

    return List.generate(maps.length, (i) {
      return Participante(
        id: maps[i]['id'],
        idInterno: maps[i]['idInterno'] ?? '',
        nombre: maps[i]['nombre'] ?? '',
        fotoUrl: maps[i]['fotoUrl'],
        activo: true, // Siempre true porque ya filtramos
        createdAt: maps[i]['createdAt'] != null 
            ? DateTime.parse(maps[i]['createdAt']) 
            : null,
      );
    });
  }

  // REMOVER PARTICIPANTES INACTIVOS DEL CACHE
  Future<void> removerParticipantesInactivos() async {
    final db = await database;
    
    final result = await db.delete(
      'participantes',
      where: 'activo = 0',
    );
    
    if (result > 0) {
      print('🗑️ $result participantes inactivos eliminados del cache local');
    } else {
      print('✅ No hay participantes inactivos en cache');
    }
  }

  // ACTUALIZAR ESTADO DE PARTICIPANTES EXISTENTES
  Future<void> actualizarEstadoParticipantes(List<Participante> nuevosParticipantes) async {
    final db = await database;
    
    final batch = db.batch();
    int actualizados = 0;
    
    for (final participante in nuevosParticipantes) {
      batch.update(
        'participantes',
        {
          'activo': participante.activo ? 1 : 0,
          'nombre': participante.nombre,
          'fotoUrl': participante.fotoUrl,
          'syncStatus': 1,
        },
        where: 'id = ?',
        whereArgs: [participante.id],
      );
      actualizados++;
    }
    
    await batch.commit();
    print('🔄 Estados actualizados para $actualizados participantes');
  }

  // LIMPIAR CACHE COMPLETO DE PARTICIPANTES
  Future<void> clearParticipantesCache() async {
    final db = await database;
    
    await db.delete('participantes');
    print('🧹 Cache de participantes limpiado completamente');
  }

  // DIAGNÓSTICO: VER TODOS LOS PARTICIPANTES EN CACHE
  Future<Map<String, dynamic>> diagnosticarCacheParticipantes() async {
    final db = await database;
    
    final todos = await db.query('participantes');
    final activos = await db.query('participantes', where: 'activo = 1');
    final inactivos = await db.query('participantes', where: 'activo = 0');
    
    return {
      'total': todos.length,
      'activos': activos.length,
      'inactivos': inactivos.length,
      'detalle_inactivos': inactivos.map((p) => {
        'id': p['id'],
        'idInterno': p['idInterno'],
        'nombre': p['nombre'],
      }).toList(),
    };
  }

  // ============ MÉTODOS PARA EVALUACIONES ============

  // GUARDAR EVALUACIÓN PENDIENTE (cuando no hay internet)
  Future<String> guardarEvaluacionPendiente({
    required String juezId,
    required String juezNombre,
    required String participanteId,
    required String participanteNombre,
    required String? categoriaId,
    required String? categoriaNombre,
    required Map<String, double> puntajes,
    required Map<String, String> comentarios,
    required double puntajeTotal,
  }) async {
    final db = await database;
    
    final evaluacionId = 'pendiente_${DateTime.now().millisecondsSinceEpoch}_${juezId}';
    
    await db.insert(
      'evaluaciones_pendientes',
      {
        'id': evaluacionId,
        'juezId': juezId,
        'juezNombre': juezNombre,
        'participanteId': participanteId,
        'participanteNombre': participanteNombre,
        'categoriaId': categoriaId,
        'categoriaNombre': categoriaNombre,
        'puntajes': _mapToJson(puntajes),
        'comentarios': _mapToJson(comentarios),
        'puntajeTotal': puntajeTotal,
        'timestamp': DateTime.now().toIso8601String(),
        'estado': 'pendiente',
        'intentosEnvio': 0,
      },
    );
    
    print('📥 Evaluación guardada localmente: $evaluacionId');
    return evaluacionId;
  }

  // OBTENER EVALUACIONES PENDIENTES
  Future<List<Map<String, dynamic>>> getEvaluacionesPendientes() async {
    final db = await database;
    return await db.query(
      'evaluaciones_pendientes',
      where: "estado = 'pendiente' OR estado = 'error'",
      orderBy: 'timestamp',
    );
  }

  // MARCAR EVALUACIÓN COMO ENVIADA
  Future<void> marcarEvaluacionEnviada(String evaluacionId) async {
    final db = await database;
    await db.update(
      'evaluaciones_pendientes',
      {'estado': 'exitoso'},
      where: 'id = ?',
      whereArgs: [evaluacionId],
    );
  }

  // AUMENTAR CONTADOR DE INTENTOS
  Future<void> aumentarIntentoEnvio(String evaluacionId, String error) async {
    final db = await database;
    
    final evaluacion = await db.query(
      'evaluaciones_pendientes',
      where: 'id = ?',
      whereArgs: [evaluacionId],
    );
    
    if (evaluacion.isNotEmpty) {
      final intentosActuales = evaluacion.first['intentosEnvio'] as int;
      
      await db.update(
        'evaluaciones_pendientes',
        {
          'intentosEnvio': intentosActuales + 1,
          'ultimoIntento': DateTime.now().toIso8601String(),
          'estado': intentosActuales >= 3 ? 'error_fatal' : 'error',
        },
        where: 'id = ?',
        whereArgs: [evaluacionId],
      );
      
      // Guardar log del error
      await db.insert('logs_sync', {
        'accion': 'intento_envio',
        'datos': 'Evaluacion: $evaluacionId',
        'timestamp': DateTime.now().toIso8601String(),
        'exito': 0,
        'error': error,
      });
    }
  }

  // VERIFICAR SI HAY EVALUACIONES PENDIENTES
  Future<bool> tieneEvaluacionesPendientes() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM evaluaciones_pendientes WHERE estado IN ('pendiente', 'error')"
    ));
    return count != null && count > 0;
  }

  // LIMPIAR EVALUACIONES EXITOSAS (más de 7 días)
  Future<void> limpiarEvaluacionesAntiguas() async {
    final db = await database;
    final sieteDiasAtras = DateTime.now().subtract(const Duration(days: 7));
    
    await db.delete(
      'evaluaciones_pendientes',
      where: 'estado = ? AND timestamp < ?',
      whereArgs: ['exitoso', sieteDiasAtras.toIso8601String()],
    );
  }

  // ============ MÉTODOS AUXILIARES ============

  String _mapToJson(Map<String, dynamic> map) {
    return map.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
  }

  Map<String, dynamic> _jsonToMap(String json) {
    final Map<String, dynamic> map = {};
    final entries = json.split(',');
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final key = parts[0].replaceAll('"', '').trim();
        final value = parts[1].replaceAll('"', '').trim();
        map[key] = value;
      }
    }
    return map;
  }
}