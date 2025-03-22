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

  Future<void> inserirPonto(Ponto ponto) async {
    final db = await database;
    await db.insert('pontos', ponto.toMap());
  }

  Future<List<Ponto>> listarPontosPorData(DateTime data) async {
    final db = await database;
    final inicio = DateTime(data.year, data.month, data.day);
    final fim = inicio.add(Duration(days: 1));
    final result = await db.query(
      'pontos',
      where: 'dataHora >= ? AND dataHora < ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'dataHora ASC',
    );
    return result.map((json) => Ponto.fromMap(json)).toList();
  }

  Future<void> atualizarPonto(Ponto ponto) async {
    final db = await database;
    await db.update(
      'pontos',
      ponto.toMap(),
      where: 'id = ?',
      whereArgs: [ponto.id],
    );
  }

  Future<List<Ponto>> listarPontosPorPeriodo(DateTime inicio, DateTime fim) async {
    final db = await database;
    final result = await db.query(
      'pontos',
      where: 'dataHora >= ? AND dataHora <= ?',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'dataHora ASC',
    );
    return result.map((json) => Ponto.fromMap(json)).toList();
  }

  Future<void> deletarPonto(int id) async {
    final db = await database;
    await db.delete(
      'pontos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}