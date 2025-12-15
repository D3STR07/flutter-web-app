import 'package:reina_nochebuena/data/local_db/calificacion_dao.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'evento_db.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de etapas
    await db.execute('''
      CREATE TABLE etapas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        subtitle TEXT,
        color TEXT NOT NULL,
        order INTEGER NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT,
        maxScore INTEGER,
        type TEXT NOT NULL,
        categoriaId TEXT,
        categoriaNombre TEXT,
        fechaInicio TEXT,
        fechaFin TEXT,
        minParticipantes INTEGER DEFAULT 1,
        maxParticipantes INTEGER DEFAULT 20,
        requiereVotacionUnica INTEGER DEFAULT 1,
        configuracion TEXT,
        isSynced INTEGER DEFAULT 1,
        lastUpdated TEXT NOT NULL,
        UNIQUE(id)
      )
    ''');

    // Índices para mejorar rendimiento
    await db.execute('CREATE INDEX idx_etapas_status ON etapas(status)');
    await db.execute('CREATE INDEX idx_etapas_order ON etapas(order)');
    await db.execute('CREATE INDEX idx_etapas_isSynced ON etapas(isSynced)');

    // Tabla para operaciones pendientes de sincronización
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
        table_name TEXT NOT NULL,
        data TEXT NOT NULL, -- JSON del objeto
        createdAt TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        lastAttempt TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migraciones futuras
    if (oldVersion < 2) {
      // Ejemplo de migración
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Métodos utilitarios
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('etapas');
    await db.delete('sync_queue');
  }

  Future<bool> hasData() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM etapas')
    );
    return count != null && count > 0;
  }

  // Para sincronización
  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'attempts < 3',
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> markAsSynced(int syncId) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [syncId]);
  }

  Future<void> incrementAttempt(int syncId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET attempts = attempts + 1, lastAttempt = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), syncId]);
  }

   // AGREGAR: Inicializar tablas de calificaciones
  Future<void> initCalificacionesTables() async {
    final db = await database;
    await CalificacionDao.createTable(db);
  }
  
  // AGREGAR: Obtener DAO de calificaciones
  CalificacionDao get calificacionDao {
    return CalificacionDao(_database!);
  }

  Future<void> marcarSincronizado(int id) async {}
}