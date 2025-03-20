import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pontocerto/models/ponto.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ponto_certo.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pontos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dataHora TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        cidade TEXT NOT NULL
      )
    ''');
  }

  Future<int> inserirPonto(Ponto ponto) async {
    final db = await database;
    return await db.insert('pontos', ponto.toMap());
  }

  Future<List<Ponto>> listarPontosPorData(DateTime data) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pontos',
      where: 'dataHora LIKE ?',
      whereArgs: ['${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}%'],
      orderBy: 'dataHora', // Adicionar ordenação por dataHora
    );

    return List.generate(maps.length, (i) {
      return Ponto.fromMap(maps[i]);
    });
  }
}