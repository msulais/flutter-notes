import 'package:sqflite/sqflite.dart' as sql;

import '../data/database.dart';
import '../enums/database.dart';
import '../enums/image.dart';

class NoteImage {
    int _id;
    final ImageType type;
    final String source;

    NoteImage({
        required this.type,
        required this.source,
        int? id
    }) : _id = id ?? -1;

    int get id => _id;

    Future<int> insertDB([DatabaseInsertOptions? options]) async {
        int id = await Database.insert(options ?? DatabaseInsertOptions(
            databaseTable, {
                'type'  : type.name,
                'source': source,
            }
        ));
        _id = id;
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
            databaseTable, {
                'type'  : type.name,
                'source': source,
            },
            where: 'id = ?',
            whereArgs: [id]
        ));
    }

    static DatabaseTables databaseTable = DatabaseTables.images;

    static Future<List<NoteImage>> queryDB([DatabaseQueryOptions? options]) async {
        List<Map<String, dynamic>> items = await Database.query(options ?? DatabaseQueryOptions(databaseTable));
        return <NoteImage>[for (final item in items) NoteImage(
            id: item['id'],
            type: ImageType.values.byName(item['type']),
            source: item['source']
        )];
    }

    static Future<int> clearDB() async {
        return await Database.delete(DatabaseDeleteOptions(databaseTable));
    }

    static Future<void> createDB(sql.Database db) async {
        return await db.execute('''CREATE TABLE ${DatabaseTables.images.name} (
            id     INTEGER PRIMARY KEY AUTOINCREMENT,
            type   TEXT,
            source TEXT
        )''');
    }
}