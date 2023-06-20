import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sql;

import '../enums/database.dart';
import '../models/note.dart';
import '../models/label.dart';
import '../models/image.dart';

class DatabaseInsertOptions {
    final DatabaseTables table;
    final Map<String, Object?> values;
    final String? nullColumnHack;
    final sql.ConflictAlgorithm? conflictAlgorithm;

    DatabaseInsertOptions(
        this.table,
        this.values, {
            this.nullColumnHack,
            this.conflictAlgorithm
        }
    );
}

class DatabaseUpdateOptions {
    final DatabaseTables table;
    final Map<String, Object?> values;
    final String? where;
    final List<Object?>? whereArgs;
    final sql.ConflictAlgorithm? conflictAlgorithm;

    DatabaseUpdateOptions(
        this.table,
        this.values, {
            this.where,
            this.whereArgs,
            this.conflictAlgorithm
        }
    );
}

class DatabaseDeleteOptions {
    final DatabaseTables table;
    final String? where;
    final List<Object?>? whereArgs;

    DatabaseDeleteOptions(
        this.table, {
            this.where,
            this.whereArgs
        }
    );
}

class DatabaseQueryOptions {
    final DatabaseTables table;
    final bool? distinct;
    final List<String>? columns;
    final String? where;
    final List<Object?>? whereArgs;
    final String? groupBy;
    final String? having;
    final String? orderBy;
    final int? limit;
    final int? offset;

    DatabaseQueryOptions(
        this.table, {
            this.distinct,
            this.columns,
            this.where,
            this.whereArgs,
            this.groupBy,
            this.having,
            this.orderBy,
            this.limit,
            this.offset
        }
    );
}

class UpdateDatabase {
    static Future<int> v1_2(sql.Database db) async {
        await db.update(
            DatabaseTables.notes.name,
            {
                'labels': jsonEncode(<int>[]),
                'images': jsonEncode(<int>[])
            }
        );
        return 2;
    }
}

class Database {
    static
    Future<File> dbFile() async {
        final directory = await getApplicationDocumentsDirectory();
        return File('${directory.path.replaceFirst(RegExp(r'/$'), '')}/database.db');
    }

    static
    Future<sql.Database> database() async => await sql.openDatabase(
        (await dbFile()).path,
        version: 2,
        onCreate: (sql.Database db, int version) async {
            await Note.createDB(db);
            await NoteLabel.createDB(db);
            await NoteImage.createDB(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
            int v = oldVersion;

            if (v == 1){
                v = await UpdateDatabase.v1_2(db);
            }

            if (v == 2){
                // TODO: later
            }

            if (v == 3){
                // TODO: later
            }
        }
    );

    static
    Future<int> insert(DatabaseInsertOptions options) async {
        return await (await database()).insert(
            options.table.name,
            options.values,
            nullColumnHack: options.nullColumnHack,
            conflictAlgorithm: options.conflictAlgorithm
        );
    }

    static
    Future<int> update(DatabaseUpdateOptions options) async {
        return await (await database()).update(
            options.table.name,
            options.values,
            where: options.where,
            whereArgs: options.whereArgs,
            conflictAlgorithm: options.conflictAlgorithm
        );
    }

    static
    Future<int> delete(DatabaseDeleteOptions options) async {
        return await (await database()).delete(
            options.table.name,
            where: options.where,
            whereArgs: options.whereArgs
        );
    }

    static
    Future<List<Map<String, dynamic>>> query(DatabaseQueryOptions options) async {
        return await (await database()).query(
            options.table.name,
            distinct: options.distinct,
            columns: options.columns,
            where: options.where,
            whereArgs: options.whereArgs,
            groupBy: options.groupBy,
            having: options.having,
            orderBy: options.orderBy,
            limit: options.limit,
            offset: options.offset
        );
    }
}