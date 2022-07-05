import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../views/download.dart';
import 'sheet.dart';
import 'syncing.dart';
import 'package:path_provider/path_provider.dart';
import '../ttwidgets/camera.dart';

class TagTagsDataPoint {
  final int typeID;
  final String value;

  TagTagsDataPoint(this.typeID, this.value);
}

class TagTagsDataset {
  final List<Map<String, dynamic>> data = [];
  final double lastModified;

  TagTagsDataset(this.lastModified);
}

class TagTagsSettings {
  int columnCount;
  bool syncOverMobile;
  bool downloadImages;
  bool acceptInvalidSSLCertificates; //Adding this because some ~4 year old (in 2021) devices (specifically Lenovo) fail to validate valid SSL certificates, at least from LetsEncrypt.
  final List<TagTagsServer> servers = [];

  TagTagsSettings(this.columnCount, this.syncOverMobile, this.downloadImages,
      this.acceptInvalidSSLCertificates);
}

class TagTagsDatabase {
  late Database _database;
  late TagTagsSettings settings;

  Future<void> _executeSQLAsset(Database db, filename) async {
    String sql = await rootBundle.loadString('assets/sql/$filename');
    List<String> cmds = sql.split(';');

    for (String cmd in cmds) {
      cmd = cmd.trim();
      if (cmd == '' || cmd.startsWith('#'))
        continue; //SQLite throws a fit if the query is blank.
      await db.execute(cmd);
    }

    print('Executed $filename');
  }

  void _onCreate(Database db, int version) async {
    print('Database onCreate');
    await _executeSQLAsset(db, 'initialize.sql');
    print('Initialized database');
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var currVersion = oldVersion;
        currVersion < newVersion;
        currVersion++) {
      await _executeSQLAsset(
          db, 'schema${currVersion}to${currVersion + 1}.sql');
    }
    print('Upgraded database from schema $oldVersion to schema $newVersion');
  }

  void _onConfigure(db) async {
    await db.execute("PRAGMA foreign_keys = ON");
  }

  Future<TagTagsDatabase> init() async {
    var path = join(await getDatabasesPath(), 'tagtags.db');
    this._database = await openDatabase(path,
        version: 3,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade);

    var s = await _database.rawQuery(
        'SELECT column_count, sync_over_mobile, download_images, accept_all_ssl_certificates FROM settings');
    settings = TagTagsSettings(
        s[0]['column_count'] as int,
        s[0]['sync_over_mobile'] == 1,
        s[0]['download_images'] == 1,
        s[0]['accept_all_ssl_certificates'] == 1);

    s = await _database
        .rawQuery('SELECT id, address, username, password FROM servers');
    for (var x = 0; x < s.length; x++) {
      settings.servers.add(TagTagsServer(
          s[x]['id'] as int,
          s[x]['address'] as String,
          s[x]['username'] as String,
          s[x]['password'] as String));
    }

    if(settings.acceptInvalidSSLCertificates) {
      HttpOverrides.global = MyHttpOverrides();
    }

    return this;
  }

  Future<void> saveServer(TagTagsServer tts) async {
    if (tts.id != null && tts.delete == false) {
      await _database.rawUpdate(
          'UPDATE servers SET address = ?, username = ?, password = ? WHERE id = ?',
          [tts.address, tts.username, tts.password, tts.id]);
    } else if (tts.id != null && tts.delete == true) {
      await _database.rawDelete('DELETE FROM servers WHERE id = ?', [tts.id]);
      settings.servers.remove(tts);
    } else if (tts.id == null) {
      tts.id = await _database.rawInsert(
          'INSERT INTO servers(address, username, password) VALUES(?,?,?)',
          [tts.address, tts.username, tts.password]);
      settings.servers.add(tts);
    }
  }

  Future<void> saveSettings() async {
    await _database.rawUpdate(
        'UPDATE settings SET column_count = ?, sync_over_mobile = ?, download_images = ?, accept_all_ssl_certificates = ?',
        [
          settings.columnCount,
          settings.syncOverMobile ? 1 : 0,
          settings.downloadImages ? 1 : 0,
          settings.acceptInvalidSSLCertificates ? 1 : 0,
        ]);
    print('Saved settings.');
  }

  Future<int> getSheetCount() async {
    List row = await _database
        .rawQuery('SELECT COALESCE(COUNT(*), 0) "c" FROM sheets');
    if (row.length == 0) return Future.error("Could not get sheet count");

    return row[0]['c'];
  }

  Future<double> getMostRecentSyncTime(String project) async {
    List row = await _database.rawQuery(
        'SELECT MAX(synctime) "synctime" FROM sync_log WHERE project = ?',
        [project]);
    if (row.length == 0)
      return Future.error("Could not get most recent synctime");

    return row[0]['synctime'];
  }

  double getCurrentTime() {
    return DateTime.now().millisecondsSinceEpoch / 1000.0;
  }

  Future<void> insertNewSyncTime(
      String project, double synctime, bool manual) async {
    int m = manual ? 1 : 0;
    await _database.rawInsert(
        'INSERT INTO sync_log(project, synctime, manual) VALUES(?,?,?)',
        [project, synctime, m]);
  }

  Future<List<String>> getSyncableProjects() async {
    List<String> projs = [];
    var rows = await _database.rawQuery(
        'SELECT DISTINCT s.project FROM sheets s LEFT JOIN projects p ON p.project = s.project WHERE p.server_id IS NOT NULL');
    for (var x = 0; x < rows.length; x++) {
      projs.add(rows[x]['project'] as String);
    }

    return projs;
  }

  Future<TagTagsServer> getProjectServer(String project) async {
    var row = await _database.rawQuery(
        'SELECT s.id, s.address, s.username, s.password FROM projects p LEFT JOIN servers s on p.server_id = s.id WHERE p.project = ?',
        [project]);
    if (row.length < 1)
      return Future.error(
          "Could not determine server details for project $project");

    return TagTagsServer(row[0]['id'] as int, row[0]['address'] as String,
        row[0]['username'] as String, row[0]['password'] as String);
  }

  Future<List<SheetDetails>> getSheets() async {
    List<SheetDetails> s = [];
    var rows = await _database.rawQuery(
        "SELECT s.id sheet_id, s.name sheet_name, s.project sheet_project, s.version sheet_version, s2.id server_id, s2.address server_address, s2.username server_username, s2.password server_password FROM sheets s LEFT JOIN projects p on s.project = p.project LEFT JOIN servers s2 on p.server_id = s2.id ORDER BY s.name");
    if (rows.length == 0) return [];

    for (var x = 0; x < rows.length; x++) {
      s.add(new SheetDetails(
          id: rows[x]['sheet_id'] as String,
          name: rows[x]['sheet_name'] as String,
          project: rows[x]['sheet_project'] as String,
          version: rows[x]['sheet_version'] as int,
          existsInDB: true,
          server: new TagTagsServer(
              rows[x]['server_id'] as int,
              rows[x]['server_address'] as String,
              rows[x]['server_username'] as String,
              rows[x]['server_password'] as String,
          )
      ));
    }

    return s;
  }

  Future<TagTagsSheetData> getSheet(String project, String id) async {
    Map attributes;

    var rows =
        await _database.rawQuery("SELECT sheet, project, name, version FROM sheets WHERE project = ? AND id = ?", [project, id]);
    if (rows.length == 0) {
      return Future.error("Could not acquire that sheet.");
    }
    attributes = jsonDecode(rows[0]['sheet'] as String);

    Map<String, TagTagsDataPoint> identComps = await _getIdentifierComps(project, id);

    return TagTagsSheetData(id, rows[0]['project']! as String, rows[0]['name']! as String, rows[0]['version']! as int, attributes, identComps);
  }

  Future<TagTagsSheetData> insertSheet(RawTagTagsSheetData sheet, int? server) async {
    Map data;
    try {
      data = jsonDecode(sheet.sheet);
    } on FormatException catch (e) {
      print(e);
      return Future.error(e);
    } catch (e) {
      print('Unexpected error: $e');
      return Future.error(e);
    }

    TagTagsSheetData sheetData;
    try {
      sheetData = TagTagsSheetData(sheet.id, sheet.project, sheet.name, sheet.version, data, {});
    } on TagTagsSheetDataFormatException catch (e) {
      print(e.errMsg);
      return Future.error(e.errMsg);
    } catch (e) {
      print(e);
      return Future.error("Unexpected error while parsing the protocol");
    }

    await addProjectIfNew(sheet.project, server);

    try {
      print('Version: ${sheet.version}, Project: ${sheet.project}, ID: ${sheet.id}');

      List<Map<String,Object?>> rows = await _database.rawQuery('SELECT id FROM sheets WHERE project = ? AND name = ?', [sheet.project, sheet.name]);
      if(rows.isEmpty) {
        await _database.rawInsert(
            'INSERT INTO sheets(id, project, name, version, sheet) VALUES(?,?,?,?,?)',
            [sheet.id, sheet.project, sheet.name, sheet.version, sheet.sheet]);

        return sheetData;
      } else if(rows[0]['id'] as String != sheet.id) {
        await _database.rawDelete('DELETE FROM identifiers WHERE sheet_id = ? AND project = ?', [rows[0]['id'] as String, sheet.project]);
      }

      var count = await _database.rawUpdate('''
        UPDATE sheets 
        SET id = ?, version = ?, sheet = ? 
        WHERE project = ? AND name = ?
      ''', [sheet.id, sheet.version, sheet.sheet, sheet.project, sheet.name]);

      print('Updated: $count');
    } catch (e) {
      print('Could not insert sheet, ${e.toString()}');
      return Future.error("Could not save the sheet in the database");
    }

    return sheetData;
  }

  Future<void> deleteSheet(String id, String project) async {
    try {
      await _database.rawDelete('DELETE FROM sheets WHERE id = ? AND project = ?', [id, project]);
    } catch(e) {
      return Future.error(e);
    }
  }

  Future<void> addProjectIfNew(String project, int? server) async {
    if (server != null) {
      await _database.rawUpdate('''
        UPDATE projects SET server_id = ? WHERE project = ?
      ''', [server, project]);
    }

    try {
      await _database.rawInsert('''
        INSERT INTO projects(project, server_id)
        VALUES (?,?)
      ''', [project, server]);
    } catch (e) {
      print("Assuming project '$project' already exists: ${e.toString()}");
    }
  }

  Future<bool> saveData(String project, String identifier, String parameter,
      int type, String value, double? modified, bool synced) async {
    int count = 0;

    try {
      count = await _database.rawUpdate("""
        UPDATE data SET 
          type_id = ?,
          value = ?,
          modified = ?,
          synced = ?
        WHERE project = ? AND identifier = ? AND parameter = ?""", [
        type,
        value,
        (modified != null ? modified : getCurrentTime()),
        (synced ? 1 : 0),
        project,
        identifier,
        parameter
      ]);
    } catch (e) {
      print('Couldnt update datapoint!');
      print(e);
      return false;
    }

    if (count > 0) return true;

    try {
      await _database.rawInsert(
          "INSERT INTO data(project, identifier, parameter, type_id, value, modified, synced) VALUES(?,?,?,?,?,?,?)",
          [
            project,
            identifier,
            parameter,
            type,
            value,
            (modified != null ? modified : getCurrentTime()),
            (synced ? 1 : 0)
          ]);
    } catch (e) {
      print('Couldnt insert datapoint!');
      print(e);
      return false;
    }

    return true;
  }

  Future<bool> saveDataCollection(List<dynamic> dc) async {
    for (var x = 0; x < dc.length; x++) {
      var dp = dc[x];
      if (await saveData(dp['project'], dp['identifier'], dp['parameter'],
              dp['type_id'], dp['value'], dp['modified'].toDouble(), true) ==
          false) {
        print('Couldnt save datapoint collection!');
        return false;
      }
    }

    return true;
  }

  Future<List<String>> getIdentifiers(String project) async {
    List<String> idents = [];
    var rows = await _database.rawQuery(
        'SELECT DISTINCT identifier FROM data WHERE project = ? ORDER BY modified DESC',
        [project]);

    for (var x = 0; x < rows.length; x++) {
      idents.add(rows[x]['identifier'] as String);
    }

    return idents;
  }

  Future<bool> saveIdentifierComponent(
      String sheet, String project, String parameter, int type, String value) async {
    int count = 0;

    try {
      count = await _database.rawUpdate("""
        UPDATE identifiers SET 
          type_id = ?,
          value = ?
        WHERE sheet_id = ? AND project = ? AND parameter = ?""",
          [type, value, sheet, project, parameter]);
    } catch (e) {
      print(e);
      return false;
    }

    if (count > 0) return true;

    try {
      await _database.rawInsert(
          "INSERT INTO identifiers(sheet_id, project, parameter, type_id, value) VALUES(?,?,?,?,?)",
          [sheet, project, parameter, type, value]);
    } catch (e) {
      print(e);
      return false;
    }

    return true;
  }

  Future<List<String>> getProjects() async {
    List<String> p = [];

    var rows = await _database.rawQuery('SELECT DISTINCT project FROM data');
    for (var x = 0; x < rows.length; x++) {
      p.add(rows[x]['project'] as String);
    }

    return p;
  }

  Future<TagTagsDataset> getUnsyncedBasicData(String project) async {
    var row = await _database.rawQuery(
        'SELECT COALESCE(MAX(modified), 0.0) "mod" FROM data WHERE synced = 0 AND project = ? AND type_id <> ?',
        [project, CAMERA_TYPE]);
    double mm = row[0]['mod'] as double;
    var ttds = TagTagsDataset(mm);

    if (mm == 0) {
      return ttds;
    }

    try {
      var rows = await _database.rawQuery(
          'SELECT identifier, parameter, type_id, value, modified FROM data WHERE modified <= ? AND project = ? AND type_id <> ? AND synced = 0',
          [mm, project, CAMERA_TYPE]);
      for (var x = 0; x < rows.length; x++) {
        ttds.data.add({
          'project': project,
          'identifier': rows[x]['identifier'],
          'parameter': rows[x]['parameter'],
          'type_id': rows[x]['type_id'],
          'value': rows[x]['value'],
          'modified': rows[x]['modified']
        });
      }
    } catch (e) {
      print(e);
      return Future.error(
          "Could not query database for unsynchronised basic data.");
    }

    return ttds;
  }

  Future<TagTagsDataset> getUnsyncedComplexData(String project) async {
    var row = await _database.rawQuery(
        'SELECT COALESCE(MAX(modified), 0.0) "mod" FROM data WHERE synced = 0 AND project = ? AND type_id = ?',
        [project, CAMERA_TYPE]);
    double mm = row[0]['mod'] as double;
    var ttds = TagTagsDataset(mm);

    if (mm == 0) {
      return ttds;
    }

    try {
      var rows = await _database.rawQuery(
          'SELECT identifier, parameter, type_id, value, modified FROM data WHERE modified <= ? AND project = ? AND type_id = ? AND synced = 0',
          [mm, project, CAMERA_TYPE]);
      for (var x = 0; x < rows.length; x++) {
        ttds.data.add({
          'project': project,
          'identifier': rows[x]['identifier'],
          'parameter': rows[x]['parameter'],
          'type_id': rows[x]['type_id'],
          'value': rows[x]['value'],
          'modified': rows[x]['modified']
        });
      }
    } catch (e) {
      print(e);
      return Future.error(
          "Could not query database for unsynchronised complex data.");
    }

    return ttds;
  }

  Future<void> setUnsyncedBasicDataToSynced(
      String project, double toModTime) async {
    await _database.rawUpdate(
        "UPDATE data SET synced = 1 WHERE synced = 0 AND modified <= ? AND project = ? AND type_id <> ?",
        [toModTime, project, CAMERA_TYPE]);
  }

  Future<void> setDataPointSynced(Map<String, dynamic> dp) async {
    await _database.rawUpdate(
        'UPDATE data SET synced = 1 WHERE project = ? AND identifier = ? AND parameter = ? AND type_id = ? AND value = ? AND modified = ?',
        [
          dp['project'],
          dp['identifier'],
          dp['parameter'],
          dp['type_id'],
          dp['value'],
          dp['modified']
        ]);
  }

  Future<List<String>> getMissingComplexData(String project) async {
    List<String> fnames = [];
    List<Map<String, Object?>> rows;
    var path = await getApplicationDocumentsDirectory();

    try {
      rows = await _database.rawQuery(
          "SELECT value FROM data WHERE project = ? AND type_id = 8 AND synced = 1 AND value <> ''",
          [project]);
    } catch (e) {
      return Future.error('Could not query the database: $e');
    }

    for (var x = 0; x < rows.length; x++) {
      var fname = rows[x]['value'] as String;
      var f = File(join(path.path, fname));
      if (!f.existsSync()) fnames.add(fname);
    }

    return fnames;
  }

  Future<String> exportData(String project) async {
    List<String> cols = [];
    List<String> out = [];

    var r = await _database.rawQuery(
        'SELECT DISTINCT parameter FROM data WHERE project = ? ORDER BY modified',
        [project]);

    List<String> row1 = ['identifier'];
    for (var x = 0; x < r.length; x++) {
      var p = r[x]['parameter'] as String;
      row1.add(p);
      cols.add(
          'COALESCE((SELECT value FROM "data" d WHERE d.identifier = i.identifier AND d.project = i.project AND "parameter" = \'$p\'), \'\') "$p"');
    }
    out.add(row1.join('\t'));

    var c = cols.join(',');
    var sql = '''
      SELECT
        i.identifier,
        $c
      FROM (SELECT DISTINCT identifier, project FROM "data" WHERE project = ?) i
    ''';

    r = await _database.rawQuery(sql, [project]);

    for (var x = 0; x < r.length; x++) {
      List<String> row = [];
      for (var y = 0; y < row1.length; y++) {
        var p = row1[y];
        row.add(r[x][p] as String);
      }
      out.add(row.join('\t'));
    }

    return out.join('\n');
  }

  Future<Map<String, TagTagsDataPoint>> _getIdentifierComps(String project, String sheet) async {
    Map<String, TagTagsDataPoint> m = {};

    try {
      var rows = await _database.rawQuery(
          "SELECT parameter, type_id, value FROM identifiers WHERE project = ? AND sheet_id = ?",
          [project, sheet]);

      for (var x = 0; x < rows.length; x++) {
        String p = rows[x]['parameter'] as String;
        int t = rows[x]['type_id'] as int;
        String v = rows[x]['value'] as String;

        m[p] = TagTagsDataPoint(t, v);
      }

      return m;
    } catch (e) {
      print(e);
      return {};
    }
  }

  Future<Map<String, TagTagsDataPoint>> getIdentifierData(
      String project, String ident) async {
    Map<String, TagTagsDataPoint> m = {};

    m['identifier'] = TagTagsDataPoint(1, ident);

    try {
      var rows = await _database.rawQuery(
          "SELECT parameter, type_id, value FROM data WHERE project = ? AND identifier = ?",
          [project, ident]);

      for (var x = 0; x < rows.length; x++) {
        String p = rows[x]['parameter'] as String;
        int t = rows[x]['type_id'] as int;
        String v = rows[x]['value'] as String;

        m[p] = TagTagsDataPoint(t, v);
      }

      return m;
    } catch (e) {
      print(e);
      return {};
    }
  }
}

//Thanks to Ma'moon Al-Akash on Stack overflow
//This feels ugly, but issues with specific tablets (e.g. Lenovo) made me add this as an alternative.
class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}