// ignore_for_file: empty_catches
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sql;

import '../data/database.dart';
import '../enums/database.dart';
import '../enums/note.dart';
import 'image.dart';
import 'label.dart';

class Note {
    NoteStatus _status;
    int id;
    String title;
    String content;
    List<NoteLabel> labels;
    List<NoteImage> images;
    DateTime? dateDeleted;
    DateTime dateModified;
    DateTime dateCreated;

    Note({
        required this.id,
        required this.title,
        required this.content,
        required this.dateCreated,
        required this.dateModified,
        required NoteStatus status,
        List<NoteLabel>? labels,
        List<NoteImage>? images,
        this.dateDeleted,
    }) :
        _status = status,
        labels = labels ?? List.empty(growable: true),
        images = images ?? List.empty(growable: true)
    ;

    Note.newNote({
        required this.title,
        required this.content,
        required NoteStatus status,
        List<NoteLabel>? labels,
        List<NoteImage>? images,
        DateTime? reminder,
    }) :
        id = -1,
        _status = status,
        dateCreated  = DateTime.now(),
        dateModified = DateTime.now(),
        labels = labels ?? List.empty(growable: true),
        images = images ?? List.empty(growable: true)
    ;

    NoteStatus
    get status => _status;

    bool
    get isEmpty => title.trim().isEmpty && content.trim().isEmpty && images.isEmpty;

    bool
    get isNotEmpty => !isEmpty;

    bool
    get shouldDeleted {
        if (dateDeleted != null) return dateDeleted!.isBefore(DateTime.now());
        return false;
    }

    void copy(Note note){
        setStatus(note.status);
        id = note.id;
        title = note.title;
        content = note.content;
        labels = List.from(note.labels);
        images = List.from(note.images);
        dateDeleted = note.dateDeleted;
        dateModified = note.dateModified;
        dateCreated = note.dateCreated;
    }

    void setStatus(NoteStatus value){
        DateTime now = DateTime.now();
        _status = value;
        dateDeleted = value == NoteStatus.trash? DateTime(
            now.year,
            now.month,
            now.day + 7, // note will deleted after 7 days
            now.hour,
            now.minute
        ) : null;
    }

    Future<int> insertDB([DatabaseInsertOptions? options]) async {
        int id = await Database.insert(options ?? DatabaseInsertOptions(
            databaseTable, {
                'title'       : title,
                'content'     : content,
                'labels'      : jsonEncode(labels.map((label) => label.id).toList()),
                'images'      : jsonEncode(images.map((img) => img.id).toList()),
                'status'      : _status.name,
                'dateCreated' : dateCreated.toIso8601String(),
                'dateModified': dateModified.toIso8601String(),
                'dateDeleted' : dateDeleted?.toIso8601String(),
            }
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
            databaseTable, {
                'title'       : title,
                'content'     : content,
                'labels'      : jsonEncode(labels.map((label) => label.id).toList()),
                'images'      : jsonEncode(images.map((img) => img.id).toList()),
                'status'      : _status.name,
                'dateCreated' : dateCreated.toIso8601String(),
                'dateModified': dateModified.toIso8601String(),
                'dateDeleted' : dateDeleted?.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id]
        ));
    }

    Future<void> updateNoteLabels() async {
        List<Map<String, dynamic>> labels = await Database.query(DatabaseQueryOptions(DatabaseTables.labels));
        List<int> ids = [];
        for (NoteLabel label in this.labels) {
            ids.add(label.id);
        }

        this.labels.clear();
        for (int id in ids){
            try {
                Map<String, dynamic>? label = labels.singleWhere((element) => id == element['id']);
                this.labels.add(NoteLabel(
                    id: label['id'],
                    name: label['name'],
                    color: Color(label['color'])
                ));
            } catch (e){}
        }
    }

    @override
    bool operator ==(Object other){
        if (other is! Note) return false;

        List<NoteImage> img = List.from(images)..sort((a, b) => a.id.compareTo(b.id));
        List<NoteLabel> lbl = List.from(labels)..sort((a, b) => a.id.compareTo(b.id));

        List<NoteImage> oimg = List.from(other.images)..sort((a, b) => a.id.compareTo(b.id));
        List<NoteLabel> olbl = List.from(other.labels)..sort((a, b) => a.id.compareTo(b.id));
        return
            _status == other.status  &&
            title   == other.title   &&
            content == other.content &&
            lbl.join(';') == olbl.join(';') &&
            img.join(';') == oimg.join(';')
        ;
    }

    @override
    int get hashCode => _status.hashCode ^ id.hashCode ^ title.hashCode ^ content.hashCode ^ labels.hashCode ^ images.hashCode ^ dateDeleted.hashCode ^ dateModified.hashCode ^ dateCreated.hashCode;

    static DatabaseTables databaseTable = DatabaseTables.notes;

    static Future<List<Note>> queryDB([DatabaseQueryOptions? options]) async {
        List<Map<String, dynamic>> items = await Database.query(options ?? DatabaseQueryOptions(databaseTable));
        List<int> labelIds = [];
        List<int> imageIds = [];
        for (final item in items){
            labelIds.addAll(List<int>.from(jsonDecode(item['labels'])));
            imageIds.addAll(List<int>.from(jsonDecode(item['images'])));
        }

        List<NoteLabel> labels = await NoteLabel.queryDB(DatabaseQueryOptions(
            NoteLabel.databaseTable,
            where: 'id IN (${[for (int i = 0; i < labelIds.length; i++) '?'].join(', ')})',
            whereArgs: [for (int id in labelIds) id]
        ));

        List<NoteImage> images = await NoteImage.queryDB(DatabaseQueryOptions(
            NoteImage.databaseTable,
            where: 'id IN (${[for (int i = 0; i < imageIds.length; i++) '?'].join(', ')})',
            whereArgs: [for (int id in imageIds) id]
        ));

        return <Note>[for (var item in items) Note(
            id          : item['id'] as int,
            title       : item['title'] as String,
            content     : item['content'] as String,
            labels      : (){
                List<int> ids = List<int>.from(jsonDecode(item['labels']));
                return labels.where((label) => ids.contains(label.id)).toList();
            }(),
            images      : (){
                List<int> ids = List<int>.from(jsonDecode(item['images']));
                return images.where((image) => ids.contains(image.id)).toList();
            }(),
            status      : NoteStatus.values.byName(item['status']),
            dateDeleted : item['dateDeleted'] == null? null : DateTime.parse(item['dateDeleted'] as String),
            dateCreated : DateTime.parse(item['dateCreated'] as String),
            dateModified: DateTime.parse(item['dateModified'] as String),
        )];
    }

    static Future<int> clearDB() async {
        return await Database.delete(DatabaseDeleteOptions(databaseTable));
    }

    static Future<void> createDB(sql.Database db) async {
        return await db.execute('''CREATE TABLE ${DatabaseTables.notes.name} (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            title        TEXT,
            content      TEXT,
            labels       TEXT,
            images       TEXT,
            status       TEXT,
            dateCreated  TEXT,
            dateModified TEXT,
            dateDeleted  TEXT
        )''');
    }
}