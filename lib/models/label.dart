import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sql;

import '../data/database.dart';
import '../enums/database.dart';

class NoteLabel {
    int id;
    String name;
    Color color;

    NoteLabel({
        required this.id,
        required this.name,
        required this.color
    });

    ColorScheme colorScheme([Brightness brightness = Brightness.light]){
        return ColorScheme.fromSeed(seedColor: color, brightness: brightness);
    }

    Future<int> insertDB([DatabaseInsertOptions? options]) async {
        int id = await Database.insert(options ?? DatabaseInsertOptions(
            databaseTable, { 'name': name, 'color': color.value }
        ));
        this.id = id;
        return id;
    }

    Future<int> deleteDB([DatabaseDeleteOptions? options]) async {
        return await Database.delete(options ?? DatabaseDeleteOptions(
            databaseTable,
            where: 'id = ?',
            whereArgs: [id]
        ));
    }

    Future<int> updateDB([DatabaseUpdateOptions? options]) async {
        return await Database.update(options ?? DatabaseUpdateOptions(
            databaseTable, { 'name': name, 'color': color.value },
            where: 'id = ?',
            whereArgs: [id]
        ));
    }

    static const
    List<Color> colors = [
        Colors.pink      ,
        Colors.red       ,
        Colors.deepOrange,
        Colors.orange    ,
        Colors.amber     ,
        Colors.yellow    ,
        Colors.lime      ,
        Colors.lightGreen,
        Colors.green     ,
        Colors.teal      ,
        Colors.cyan      ,
        Colors.lightBlue ,
        Colors.blue      ,
        Colors.indigo    ,
        Colors.deepPurple,
        Colors.purple    ,
        Colors.brown     ,
    ];

    static
    NoteLabel from(NoteLabel label){
        return NoteLabel(id: label.id, name: label.name, color: label.color);
    }

    static
    DatabaseTables databaseTable = DatabaseTables.labels;

    static
    Future<List<NoteLabel>> queryDB([DatabaseQueryOptions? options]) async {
        List<Map<String, dynamic>> items = await Database.query(options ?? DatabaseQueryOptions(databaseTable));
        return [for (var item in items) NoteLabel(
            id   : item['id'] as int,
            name : item['name'] as String,
            color: Color(item['color'] as int)
        )];
    }

    static
    Future<int> clearDB() async {
        return await Database.delete(DatabaseDeleteOptions(databaseTable));
    }

    static
    Future<void> createDB(sql.Database db) async {
        return await db.execute('''CREATE TABLE ${DatabaseTables.labels.name} (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            name  TEXT,
            color INTEGER
        )''');
    }
}