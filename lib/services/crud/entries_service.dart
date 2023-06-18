import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'crud_exceptions.dart'; // This one's mine!!

class EntryService {
  Database? _db;

  Future<DatabaseEntry> updateEntry(
      {required DatabaseEntry entry, required String text}) async {
    final db = _getDataBaseOrThrow();
    await getEntry(entryId: entry.id);
    // Just a stopping point for the case that the entry DNE.

    final updatesCount = await db.update(entryTable, {
      textColumn: text,
      isSyncedWithCloudColumn: 0,
    });

    if (updatesCount == 0) {
      throw CouldNotUpdateEntry();
    } else {
      return await getEntry(entryId: entry.id);
    }
  }

  Future<Iterable<DatabaseEntry>> getAllEntries() async {
    final db = _getDataBaseOrThrow();
    final entries = await db.query(
      entryTable,
    );
    return entries.map((entriesRow) => DatabaseEntry.fromRow(entries.first));
  }

  Future<DatabaseEntry> getEntry({required int entryId}) async {
    final db = _getDataBaseOrThrow();
    final entries = await db.query(
      entryTable,
      limit: 1,
      where: 'ID = ?',
      whereArgs: [entryId],
    );

    if (entries.isEmpty) {
      throw CouldNotFindEntry();
    } else {
      return DatabaseEntry.fromRow(entries.first);
    }
  }

// Hopefully i never need this one
  Future<int> deleteAllEntries() async {
    final db = _getDataBaseOrThrow();
    return await db.delete(entryTable);
  }

  // TODO: check to see if using 'entryId'
  // instead of 'id' messes things up?
  Future<void> deleteEntry({required int entryId}) async {
    final db = _getDataBaseOrThrow();
    final deletedCount = await db.delete(
      entryTable,
      where: 'ID = ?',
      whereArgs: [entryId],
    );
    if (deletedCount == 0) {
      throw CouldNotDeleteEntry();
    }
  }

  Future<DatabaseEntry> createEntry({required DatabaseUser owner}) async {
    final db = _getDataBaseOrThrow();

    final dbUser = await getUser(email: owner.email);

    // id verification. Making sure owner with the correct id
    // exists in the database
    if (dbUser != owner) {
      throw CouldNotFindUser();
    }

    // create the entry
    const text = '';
    final entryId = await db.insert(entryTable, {
      userIdColumn: owner.id,
      textColumn: text,
      isSyncedWithCloudColumn: 1,
    });

    final entry = DatabaseEntry(
      id: entryId,
      userId: owner.id,
      text: text,
      isSyncedWithCloud: true,
    );
    return entry;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    final db = _getDataBaseOrThrow();

    // First check if the user exists throw 'could not find' IF NOT
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'EMAIL = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isEmpty) {
      throw CouldNotFindUser();
    } else {
      return DatabaseUser.fromRow(results.first);
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    final db = _getDataBaseOrThrow();
    // First check if the user exists
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (results.isNotEmpty) {
      throw UserAlreadyExists();
    }

    final userId = await db.insert(userTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(
      id: userId,
      email: email,
    );
  }

  Future<void> deleteUser({required String email}) async {
    // Using our private db io function
    final db = _getDataBaseOrThrow();
    final deletedCount = await db.delete(
      userTable,
      where: 'EMAIL = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (deletedCount != 1) {
      throw CouldNotDeleteUser();
    }
  }

  // prefixed with undersoce '_' to signify PRIVATE function
  // private function will be used by our classes for database IO without
  //manual 'if statements'
  Database _getDataBaseOrThrow() {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpen();
    } else {
      return db;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpen();
    } else {
      await db.close();
      // reset db to closed!
      _db = null;
    }
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);
      _db = db; //database has now been opened.
      // Creates the user table using an execute command
      await db.execute(createUserTable);
      // Creates the diary entry table using the execute command
      await db.execute(createEntryTable);
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectory();
    }
  }
}

// Class Definitions
@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({
    required this.id,
    required this.email,
  });

  // initalisation assignment of Entry properties // mapping db user row to parameters
  // of the Database User
  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  // To describe the user when we print to consol for debugging
  @override
  String toString() => 'Person ID = $id, email = $email';

  // Defining class equality
  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  // Equality is now based on the SQLite UNIQUE id
  @override
  int get hashCode => id.hashCode;
}

class DatabaseEntry {
  final int id;
  final int userId;
  final String text;
  final bool isSyncedWithCloud;

  DatabaseEntry({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSyncedWithCloud,
  });

  // initalisation assignment of Entry properties // mapping db user row to parameters
  // of the Database Entry
  DatabaseEntry.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[emailColumn] as int,
        text = map[textColumn] as String,
        isSyncedWithCloud =
            (map[isSyncedWithCloudColumn] as int) == 1 ? true : false;

  // To describe the user when we print to consol for debugging
  @override
  String toString() =>
      'EntryId = $id, userId = $userId, isSyncedWithCloud = $isSyncedWithCloud';

  // Defining class equality
  @override
  bool operator ==(covariant DatabaseEntry other) => id == other.id;

  // Equality is now based on the SQLite UNIQUE id
  @override
  int get hashCode => id.hashCode;
}

// CONSTANTS
const dbName = 'mydiary.db'; // To be stored in the documents folder of the app.
const userTable = 'USER';
const entryTable = 'ENTRY';
const idColumn = 'ID';
const emailColumn = 'EMAIL';
const userIdColumn = 'USER_ID';
const textColumn = 'TEXT';
const isSyncedWithCloudColumn = 'IS_SYNCED_WITH_CLOUD';
const createUserTable = '''CREATE TABLE IF NOT EXISTS "USER" (
                            "ID"	INTEGER NOT NULL,
                            "EMAIL"	TEXT NOT NULL UNIQUE,
                            PRIMARY KEY("ID" AUTOINCREMENT)
                        );''';
const createEntryTable = '''CREATE TABLE IF NOT EXISTS "ENTRY" (
                              "ID"	INTEGER NOT NULL,
                              "USER_ID"	INTEGER NOT NULL,
                              "TEXT"	TEXT,
                              "IS_SYNCED_WITH_CLOUD"	INTEGER NOT NULL DEFAULT 0,
                              FOREIGN KEY("USER_ID") REFERENCES "USER"("ID"),
                              PRIMARY KEY("ID" AUTOINCREMENT)
                        );''';
