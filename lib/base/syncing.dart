import 'package:background_fetch/background_fetch.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tagtags2/views/download.dart';
import 'database.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:convert';

class SheetDetails {
  final String id;
  final String name;
  final String project;
  final int version;
  bool existsInDB;
  final TagTagsServer server;

  SheetDetails({required this.id, required this.name, required this.project, required this.version, required this.server, this.existsInDB = false});
}

Map<int,String> statusCodes = {
  //Success codes
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  203: 'Non-Authoritative Information',
  204: 'No Content',
  205: 'Reset Content',
  206: 'Partial Content',
  //Redirect codes
  300: 'Multiple Choises',
  301: 'Moved Permanently',
  302: 'Found',
  303: 'See Other',
  304: 'Not Modified',
  305: 'Use Proxy',
  307: 'Temporary Redirect',
  308: 'Permanent Redirect',
  //Client errors
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  406: 'Not Acceptable',
  408: 'Request Timeout',
  409: 'Conflict',
  410: 'Gone',
  411: 'Length Required',
  415: 'Unsupported Media Type',
  417: 'Expectation Failed',
  418: 'I\'m a teapot',
  426: 'Update Required',
  429: 'Too Many Requests',
  //Server errors
  500: 'Internal Server Error',
  501: 'Not Implemented',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Timeout',
  505: 'HTTP Version Not Supported'
};

class RawTagTagsSheetData {
  final String name;
  final String id;
  final String project;
  final String sheet;
  final int version;

  RawTagTagsSheetData({required this.name, required this.id, required this.project, required this.sheet, required this.version});
}

class TagTagsServer {
  int? id;
  String address = '';
  String username = '';
  String password = '';
  bool delete = false;

  TagTagsServer(this.id, this.address, this.username, this.password);
  TagTagsServer.blank();

  Future<List<SheetDetails>> getSheets() async {
    var c = http.Client();

    try {
      var r = await c.get(Uri.parse('$address/app/sheets'), headers: {
        'x-tagtags-username': username,
        'x-tagtags-password': password
      });

      if (r.statusCode == 200) {
        List<SheetDetails> sheets = [];
        List<dynamic> rawSheets;
        try {
          rawSheets = jsonDecode(r.body);

          for(var x = 0; x < rawSheets.length; x++) {
            sheets.add(SheetDetails(
                id: rawSheets[x]['id'].toString(),
                name: rawSheets[x]['name'] as String,
                project: rawSheets[x]['project'],
                version: rawSheets[x]['version'],
                server: this,
            ));
          }
        } catch(e) {
          return Future.error(e);
        }

        

        return sheets;
      } else {
        String msg = 'Unknown error';
        if(statusCodes.keys.contains(r.statusCode)) msg = statusCodes[r.statusCode]!;
        return Future.error('Server returned code ${r.statusCode}: $msg');
      }
    } finally {
      c.close();
    }
  }

  Future<SheetDetails> getSheetDetails(String id) async {
    var c = http.Client();
    try {
      var r = await c.get(Uri.parse('$address/app/sheets/$id/details'), headers: {
        'x-tagtags-username': username,
        'x-tagtags-password': password
      });

      if (r.statusCode == 200) {
        if(r.headers["x-tagtags-sheet-name-base64"] == null ||
            r.headers["x-tagtags-sheet-project"] == null ||
            r.headers["x-tagtags-sheet-version"] == null) {
          return Future.error("Server did not include sheet details");
        }

        return SheetDetails(
          id: id,
          name: utf8.decode(base64.decode(r.headers["x-tagtags-sheet-name-base64"]!)),
          project: r.headers["x-tagtags-sheet-project"]!,
          version: int.parse(r.headers["x-tagtags-sheet-version"]!),
          server: this
        );
      } else {
        String msg = 'Unknown error';
        if(statusCodes.keys.contains(r.statusCode)) msg = statusCodes[r.statusCode]!;
        return Future.error('Server returned code ${r.statusCode}: $msg');
      }
    } finally {
      c.close();
    }
  }

  Future<RawTagTagsSheetData> getSheet(String id) async {
    var c = http.Client();
    try {
      var r = await c.get(Uri.parse('$address/app/sheets/$id'), headers: {
        'x-tagtags-username': username,
        'x-tagtags-password': password
      });

      if (r.statusCode == 200) {
        if(r.headers["x-tagtags-sheet-name-base64"] == null ||
            r.headers["x-tagtags-sheet-project"] == null ||
            r.headers["x-tagtags-sheet-version"] == null) {
          return Future.error("Server did not include sheet details");
        }

        return RawTagTagsSheetData(
          name: utf8.decode(base64.decode(r.headers["x-tagtags-sheet-name-base64"]!)),
          id: id,
          project: r.headers["x-tagtags-sheet-project"]!,
          version: int.parse(r.headers["x-tagtags-sheet-version"]!),
          sheet: r.body
        );
      } else {
        String msg = 'Unknown error';
        if(statusCodes.keys.contains(r.statusCode)) msg = statusCodes[r.statusCode]!;
        return Future.error('Server returned code ${r.statusCode}: $msg');
      }
    } finally {
      c.close();
    }
  }

  Future<void> uploadData(TagTagsDatabase db, String project) async {
    TagTagsDataset ttds = await db.getUnsyncedBasicData(project);

    String data = jsonEncode(ttds.data);
    var c = http.Client();
    try {
      var r = await c.post(Uri.parse('$address/app/projects/$project/data'),
          headers: {
            'x-tagtags-username': username,
            'x-tagtags-password': password
          },
          body: data);

      if (r.statusCode == 200) {
        await db.setUnsyncedBasicDataToSynced(project, ttds.lastModified);
        return;
      } else {
        return Future.error('Server responded with code ${r.statusCode}');
      }
    } catch (e) {
      print(e);
      return Future.error(e);
    } finally {
      c.close();
    }
  }

  Future<bool> syncDatapoint(TagTagsDatabase db, Map<String, dynamic> dp) async {
    String data = jsonEncode(dp);
    var c = http.Client();
    try {
      var r = await c.post(Uri.parse('$address/app/projects/${dp['project']}/${dp['identifier']}/${dp['parameter']}'),
          headers: {
            'x-tagtags-username': username,
            'x-tagtags-password': password
          },
          body: data);

      if(r.statusCode == 200) {
        if(r.body != "NA") {
          var ndp = jsonDecode(r.body);
          db.saveData(ndp["project"], ndp["identifier"], ndp["parameter"], ndp["type_id"], ndp["value"], ndp["modified"].toDouble(), true);
        } else {
          db.setDataPointSynced(dp);
        }

        return true;
      }

      return false;
    } catch (e) {
      print(e);
      return false;
    } finally {
      c.close();
    }
  }

  Future<void> uploadBinaryData(Map<String, dynamic> datapoint) async {
    Directory path = await getApplicationDocumentsDirectory();
    File f = File(join(path.path, datapoint['value']));
    try {
      var bs = new http.ByteStream(Stream.castFrom(f.openRead()));
      var size = f.lengthSync();

      Uri uri =
          Uri.parse('$address/app/projects/${datapoint['project']}/data/files');
      var r = new http.MultipartRequest('POST', uri);
      r.headers.addAll(
          {'x-tagtags-username': username, 'x-tagtags-password': password});

      var mpf = new http.MultipartFile('file', bs, size,
          filename: datapoint['value']);
      r.files.add(mpf);
      r.fields['data'] = jsonEncode(datapoint);

      var reply = await r.send();

      switch (reply.statusCode) {
        case 200:
          return;
        case 401:
          return Future.error('Authentication failed.');
        case 409:
          return;
        default:
          return Future.error(
              'Unexpected error, server returned error code ${reply.statusCode}: ${await reply.stream.bytesToString()}');
      }
    } on FileSystemException catch (e) {
      return Future.error('Could not access "${datapoint["value"]}": $e');
    }
  }

  Future<List<dynamic>> downloadData(
      String project, double mostRecentSyncTime) async {
    var c = http.Client();
    try {
      var ldt = mostRecentSyncTime.toString();

      var r =
          await c.get(Uri.parse('$address/app/projects/$project/data'), headers: {
        'x-tagtags-username': username,
        'x-tagtags-password': password,
        'x-tagtags-mostrecentsync': ldt
      });

      if (r.statusCode == 200) {
        return jsonDecode(r.body);
      } else {
        print(r.statusCode);
        return Future.error('The server returned status ${r.statusCode}');
      }
    } catch (e) {
      print(e);
      return Future.error('The server could not be queried');
    } finally {
      c.close();
    }
  }

  Future<bool> downloadAndSaveData(
      TagTagsDatabase db, String project, double mostRecentSyncTime) async {
    List<dynamic> dc = await downloadData(project, mostRecentSyncTime);

    return await db.saveDataCollection(dc);
  }

  Future<void> downloadFile(String project, String filename) async {
    Directory path = await getApplicationDocumentsDirectory();
    File newFile = File(join(path.path, filename));

    var c = http.Client();
    try {
      var r = await c.get(
          Uri.parse('$address/app/projects/$project/data/files/$filename'),
          headers: {
            "x-tagtags-username": username,
            "x-tagtags-password": password
          });

      if (r.statusCode != 200) {
        return Future.error('The server returned status: ${r.statusCode}');
      }

      newFile.writeAsBytesSync(r.bodyBytes);
    } catch (e) {
      return Future.error(e);
    }
  }
}

bool backgroundSyncEnabled = false;
void backgroundSyncHeadless(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;

  if(isTimeout) {
    backgroundSyncEnabled = false;
    print("[TagTags background sync - TERM] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }

  backgroundSyncEnabled = true;
  print("[TagTags background sync - INIT] Headless sync event started.");

  TagTagsDatabase db = await TagTagsDatabase().init();
  var connectivityResult = await Connectivity().checkConnectivity();
  if(connectivityResult == ConnectivityResult.mobile && !db.settings.syncOverMobile) {
    print("[TagTags background sync - INIT] Headless sync event canceled because WiFi is not available.");
    BackgroundFetch.finish(taskId);
    return;
  }

  List<String> projects = await db.getSyncableProjects();
  for(var x = 0; x < projects.length && backgroundSyncEnabled; x++) {
    var proj = projects[x];
    var tts = await db.getProjectServer(proj);

    var ttds = await db.getUnsyncedBasicData(proj);
    for(var y = 0; y < ttds.data.length && backgroundSyncEnabled; y++) {
      var dp = ttds.data[y];

      print('[TagTags background sync - SYNC] Synchronizing datapoint: ${dp['project']}, ${dp['identifier']}, ${dp['parameter']}.');

      if(!await tts.syncDatapoint(db, dp)) {
        print('[TagTags background sync - ERROR] Could not synchronize a datapoint.');
      };
    }

    ttds = await db.getUnsyncedComplexData(proj);
    for(var y = 0; y < ttds.data.length && backgroundSyncEnabled; y++) {
      try {
        await tts.uploadBinaryData(ttds.data[y]);
        await db.setDataPointSynced(ttds.data[y]);
      } catch (e) {
        print(
            '[TagTags background sync - ERROR] Could not synchronize binary data: $e.');
      }
    }
  }

  print("[TagTags background sync - TERM] Headless task finished: $taskId");
  if(backgroundSyncEnabled) BackgroundFetch.finish(taskId);
}

Future<bool> greenForSyncing(TagTagsDatabase db) async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if(connectivityResult == ConnectivityResult.mobile && !db.settings.syncOverMobile) {
    return false;
  }

  return true;
}