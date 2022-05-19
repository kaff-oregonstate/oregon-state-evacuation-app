import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:evac_app/models/participant_location.dart';

class TrajectoryDatabaseManager {
  static const _DATABASE_FILENAME = 'trajectory.sqlite3.db';
  static const _SCHEMA_PATH = 'assets/trajectory_schema.sql';
  static const _SQL_INSERT = 'INSERT INTO trajectory(locationData) VALUES (?)';
  static const _SQL_SELECT = 'SELECT * FROM trajectory';

  static TrajectoryDatabaseManager? _instance;
  final Database db;

  TrajectoryDatabaseManager._({required Database database}) : db = database;

  factory TrajectoryDatabaseManager.getInstance() {
    assert(_instance != null);
    return _instance!;
  }

  Future<void> insert({required ParticipantLocation location}) async {
    String locJson = jsonEncode(location.toJson());
    print(locJson);
    await db.transaction((txn) async {
      try {
        await txn.rawInsert(
          _SQL_INSERT,
          [locJson],
        );
      } on DatabaseException catch (e) {
        print(e);
      }
    });
  }

  Future<List<ParticipantLocation>> getTrajectory() async {
    List<Map> trajectoryDB = await db.rawQuery(_SQL_SELECT);
    final ingredients = trajectoryDB.map((r) {
      return ParticipantLocation.fromJson(jsonDecode(r['locationData']));
    }).toList();
    return ingredients;
  }

  static Future initialize() async {
    Database db = await openDatabase(
      _DATABASE_FILENAME,
      version: 1,
      onCreate: (Database db, int version) async {
        String schema = await rootBundle.loadString(_SCHEMA_PATH);
        createTables(db, schema);
      },
    );
    _instance = TrajectoryDatabaseManager._(database: db);
  }

  Future<void> wipeData() async {
    await deleteDatabase(_DATABASE_FILENAME);
    return await initialize();
  }

  static void createTables(Database db, String sql) async {
    await db.execute(sql);
  }
}
