import 'package:background_fetch/background_fetch.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/base/syncing.dart';
import 'package:tagtags2/sync.dart';
import 'package:tagtags2/views/export.dart';
import 'package:tagtags2/views/identifier.dart';
import 'settings.dart';
import 'download.dart';
import '../alert.dart';
import '../base/database.dart';

class TagTagsStartView extends StatefulWidget {
  @override
  _TagTagsStartViewState createState() => _TagTagsStartViewState();
}

class _TagTagsStartViewState extends State<TagTagsStartView> {
  TagTagsDatabase? _db;
  List<SheetDetails>? _sheets;
  var _syncing = false;
  //Map<String, dynamic>? downloadingSheet;
  List<SheetDetails> downloadingSheets = [];

  void _updateSheets(bool initial) async {
    var s = await _db!.getSheets();
    setState(() {
      _sheets = s;
    });

    if(initial && await greenForSyncing(_db!)) {
      for(var x = 0; x < s.length; x++) {
        checkIfSheetIsOutOfDate(s[x]);
      }
    }
  }

  bool _sheetIsSyncing(SheetDetails sheet) {
    for(var x = 0; x < downloadingSheets.length; x++) {
      if(downloadingSheets[x].project == sheet.project && downloadingSheets[x].id == sheet.id) {
        return true;
      }
    }

    return false;
  }

  bool _sheetExistsInDB(SheetDetails dd) {
    for(var x = 0; x < _sheets!.length; x++) {
      if(dd.project == _sheets![x].project && dd.id == _sheets![x].id) {
        return true;
      }
    }

    return false;
  }

  void _openSheet(String project, String sheet) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TagTagsProtInitView(_db!, project, sheet);
        },
      ),
    );
  }

  void _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return TagTagsSettingsInitView(_db!);
    }));

    setState(() {});
  }

  void checkIfSheetIsOutOfDate(SheetDetails sd) async {
    var newSd = await sd.server.getSheetDetails(sd.id);

    if(newSd.version > sd.version) _getSheet(sd);
  }

  void _getSheet(SheetDetails dd) async {
    RawTagTagsSheetData data;

    dd.existsInDB = _sheetExistsInDB(dd);

    setState(() {
      downloadingSheets.add(dd);
      //downloadingSheet = dd.sheetDetails;
    });

    try {
      data = await dd.server.getSheet(dd.id);
    } catch (e) {
      noticeDialog(context, 'Server error', e.toString(), TagTagsIcons.largeErrorIcon);
      return;
    }

    try {
      await _db!.insertSheet(data, dd.server.id);
    } catch (e) {
      noticeDialog(context, 'Database error', e.toString(), TagTagsIcons.largeErrorIcon);
    }

    downloadingSheets.remove(dd);

    _updateSheets(false);
  }

  void _openDownload() async {
    SheetDetails? dd = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return TagTagsDownloadView(_db!);
    }));

    if(dd != null) _getSheet(dd);
  }

  void _openExport() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return TagTagsExportView(_db!);
    }));
  }

  void _deleteSheet(int i) async {
    var s = _sheets![i];
    if (await approvalDialog(context, 'Warning',
            "Are you sure you want to delete the sheet '${s.name}'?") ==
        true) {
      try {
        await _db!.deleteSheet(s.id, s.project);
      } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete sheet: $e'), backgroundColor: TagTagsColors.primaryColor));
      }

      setState(() {
        _sheets!.removeAt(i);
      });
    }
  }

  void _syncData() async {
    setState(() {
      _syncing = true;
    });
  }

  void _syncComplete(List<String> errors) {
    setState(() {
      _syncing = false;
    });
  }

  void _tryInitSync() async {
    if(!await greenForSyncing(_db!)) return

    _syncData();
  }

  @override
  void initState() {
    super.initState();
    TagTagsDatabase().init().then((db) {
      _db = db;
      _updateSheets(true);
      _tryInitSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_db == null)
      return Container(
          decoration: BoxDecoration(color: Colors.white),
          child: Center(
              child: Image(image: AssetImage('assets/images/tagtags2.png'))));

    return Scaffold(
      appBar: AppBar(title: Text('TagTags'), actions: [
        IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
                context: context,
                applicationLegalese:
                    'TagTags is an application for digital data collection with manual input\nCopyright (C) 2021 Kim Lindgren\n\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.',
                applicationVersion: '2.0')),
        IconButton(icon: Icon(Icons.settings), onPressed: _openSettings)
      ]),
      bottomNavigationBar: SizedBox(
          height: 64,
          child: Container(
              padding: EdgeInsets.fromLTRB(0, 0, 20, 0),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(
                    spreadRadius: 2,
                    blurRadius: 3,
                    color: Colors.grey,
                )
              ]),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _syncing ? TagTagsSyncWidget(_db!, _syncComplete) : Container(),
                  Image(image: AssetImage('assets/images/slulogo.png')),
                  Image(image: AssetImage('assets/images/siteslogo.png'))
              ]))),
      body: _buildBody()
    );
  }

  Widget _buildBody() {
    List<Widget> _tiles = [
      Visibility(
          visible: (_db != null && _db!.settings.servers.length > 0),
          child: Column(children: [
            ListTile(
                leading: TagTagsIcons.downloadIcon,
                title: Text('Download sheet from server'),
                onTap: () => _openDownload()),
            ListTile(
                leading: _syncing
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator())
                    : TagTagsIcons.syncIcon,
                title: Text(_syncing ? 'Synchronizing...' : 'Synchronize data'),
                onTap: _syncing ? null : () => _syncData()),
          ])),
      ListTile(
          leading: TagTagsIcons.exportIcon,
          title: Text('Export data'),
          onTap: () => _openExport()),
      Container(
          padding: EdgeInsets.fromLTRB(15, 5, 15, 5),
          child: Text('Sheets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
    ];

    if (_sheets != null) {
      for (var x = 0; x < _sheets!.length; x++) {
        var s = _sheets![x];
        _tiles.add(ListTile(
          leading: _sheetIsSyncing(s)
              ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator())
              : TagTagsIcons.documentIcon,
          title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Project: ${s.project} & Version: ${s.version}',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
              ]),
          onTap: () => {_openSheet(s.project, s.id)},
          onLongPress: () => _deleteSheet(x),
        ));
      }

      for(var x = 0; x < downloadingSheets.length; x++) {
        var downloadingSheet = downloadingSheets[x];

        if(downloadingSheet.existsInDB == false) {
          _tiles.add(ListTile(
            leading: SizedBox(height: 24, width: 24, child: CircularProgressIndicator()),
            title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(downloadingSheet.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black26)),
                  Text('Project: ${downloadingSheet.project} & Version: ${downloadingSheet.version}',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black26))
                ]),
          ));
        }
      }
    }

    return Container(
        decoration: BoxDecoration(color: Colors.white),
        child: ListView(children: _tiles));
  }
}
