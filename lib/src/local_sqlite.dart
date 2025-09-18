// lib/src/local_sqlite.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalSqlite {
  static Database? _db;
  static final _uuid = Uuid();

  static Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/dube_app.db';
   _db = await openDatabase(
  path,
  version: 2, // bump version for migration
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        total REAL DEFAULT 0,
        createdAt INTEGER,
        deleted INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE dubes (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        personId TEXT NOT NULL,
        itemName TEXT,
        quantity INTEGER DEFAULT 1,
        priceAtTaken REAL DEFAULT 0,
        amount REAL DEFAULT 0,
        note TEXT,
        createdAt INTEGER
      );
    ''');
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      // add userId column to existing tables
      await db.execute('ALTER TABLE people ADD COLUMN userId TEXT DEFAULT ""');
      await db.execute('ALTER TABLE dubes ADD COLUMN userId TEXT DEFAULT ""');
    }
  },
);

  }

  // Get current Firebase UID
  static String _uid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    return user.uid;
  }

  // People CRUD
  static Future<List<Map<String, dynamic>>> getAllPeople({String search = ''}) async {
    await init();
    final uid = _uid();
    final where = "deleted = 0 AND userId = ?" + (search.isNotEmpty ? " AND name LIKE ?" : "");
    final args = search.isNotEmpty ? [uid, '%$search%'] : [uid];
    final rows = await _db!.rawQuery('SELECT * FROM people WHERE $where ORDER BY createdAt ASC', args);
    return rows;
  }

  static Future<void> insertPerson(String name) async {
    await init();
    final uid = _uid();
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.insert('people', {'id': id, 'userId': uid, 'name': name, 'total': 0, 'createdAt': now, 'deleted': 0});
  }

  static Future<void> deletePerson(String id) async {
    await init();
    final uid = _uid();
    await _db!.update('people', {'deleted': 1}, where: 'id = ? AND userId = ?', whereArgs: [id, uid]);
    await _db!.delete('dubes', where: 'personId = ? AND userId = ?', whereArgs: [id, uid]);
  }

  // Dubes CRUD
  static Future<List<Map<String, dynamic>>> getDubesForPerson(String personId, {String search = ''}) async {
    await init();
    final uid = _uid();
    final where = 'personId = ? AND userId = ?' + (search.isNotEmpty ? ' AND (itemName LIKE ? OR note LIKE ?)' : '');
    final args = search.isNotEmpty ? [personId, uid, '%$search%', '%$search%'] : [personId, uid];
    final rows = await _db!.query('dubes', where: where, whereArgs: args, orderBy: 'createdAt DESC');
    return rows;
  }

  static Future<void> insertDube({
    required String personId,
    required String itemName,
    required int quantity,
    required double priceAtTaken,
    String note = '',
  }) async {
    await init();
    final uid = _uid();
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final amount = quantity * priceAtTaken;

    final batch = _db!.batch();
    batch.insert('dubes', {
      'id': id,
      'userId': uid,
      'personId': personId,
      'itemName': itemName,
      'quantity': quantity,
      'priceAtTaken': priceAtTaken,
      'amount': amount,
      'note': note,
      'createdAt': now,
    });
    batch.rawUpdate('UPDATE people SET total = total + ? WHERE id = ? AND userId = ?', [amount, personId, uid]);
    await batch.commit(noResult: true);
  }

  static Future<void> updateDube(String id, {required String itemName, required int quantity, required double priceAtTaken, String note = ''}) async {
    await init();
    final uid = _uid();
    final rows = await _db!.query('dubes', where: 'id = ? AND userId = ?', whereArgs: [id, uid]);
    if (rows.isEmpty) return;

    final oldAmount = (rows.first['amount'] as num).toDouble();
    final newAmount = quantity * priceAtTaken;
    final personId = rows.first['personId'] as String;

    final batch = _db!.batch();
    batch.update('dubes', {
      'itemName': itemName,
      'quantity': quantity,
      'priceAtTaken': priceAtTaken,
      'amount': newAmount,
      'note': note,
    }, where: 'id = ? AND userId = ?', whereArgs: [id, uid]);

    final diff = newAmount - oldAmount;
    if (diff != 0) batch.rawUpdate('UPDATE people SET total = total + ? WHERE id = ? AND userId = ?', [diff, personId, uid]);
    await batch.commit(noResult: true);
  }

  static Future<void> deleteDube(String id) async {
    await init();
    final uid = _uid();
    final rows = await _db!.query('dubes', where: 'id = ? AND userId = ?', whereArgs: [id, uid]);
    if (rows.isEmpty) return;

    final amount = (rows.first['amount'] as num).toDouble();
    final personId = rows.first['personId'] as String;

    final batch = _db!.batch();
    batch.delete('dubes', where: 'id = ? AND userId = ?', whereArgs: [id, uid]);
    batch.rawUpdate('UPDATE people SET total = total - ? WHERE id = ? AND userId = ?', [amount, personId, uid]);
    await batch.commit(noResult: true);
  }

  // Export DB to JSON file path
  static Future<String> exportDbToJsonFile() async {
    await init();
    final uid = _uid();
    final people = await _db!.query('people', where: 'userId = ?', whereArgs: [uid]); 
    final dubes = await _db!.query('dubes', where: 'userId = ?', whereArgs: [uid]);
    final dump = {
      'meta': {'version': 1, 'exportedAt': DateTime.now().toIso8601String()},
      'people': people,
      'dubes': dubes,
    };
    final jsonStr = jsonEncode(dump);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/dube_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr, flush: true);
    return file.path;
  }

  static Future<void> importJsonFileToDb(String filePath) async {
    await init();
    final uid = _uid();
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found');
    final dump = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final batch = _db!.batch();
    batch.delete('dubes', where: 'userId = ?', whereArgs: [uid]);
    batch.delete('people', where: 'userId = ?', whereArgs: [uid]);
    await batch.commit(noResult: true);

    final people = (dump['people'] as List).cast<Map<String, dynamic>>();
    final dubes = (dump['dubes'] as List).cast<Map<String, dynamic>>();
    final b2 = _db!.batch();
    for (final p in people) {
      // ensure userId matches current logged-in user
      p['userId'] = uid;
      b2.insert('people', p);
    }
    for (final d in dubes) {
      d['userId'] = uid;
      b2.insert('dubes', d);
    }
    await b2.commit(noResult: true);
  }

  static Future<void> backupToFirestore() async {
    await init();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final path = await exportDbToJsonFile();
    final file = File(path);
    final dump = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();
    final docRef = fs.collection('users').doc(user.uid).collection('backups').doc(now.millisecondsSinceEpoch.toString());
    await docRef.set({'exportedAt': Timestamp.fromDate(now), 'payload': dump});
  }

  static Future<void> restoreFromFirestoreLatestBackup() async {
    await init();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('backups')
        .orderBy('exportedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('No cloud backup found');
    final payload = snap.docs.first.data()['payload'] as Map<String, dynamic>;
    final dir = await getApplicationDocumentsDirectory();
    final temp = File('${dir.path}/tmp_cloud_backup.json');
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await importJsonFileToDb(temp.path);
  }
}
