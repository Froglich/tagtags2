import 'dart:io';

import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tagtags2/base/constants.dart';

import 'alert.dart';

String getBasename(String path) {
  return basename(path);
}

Future<Directory> pickDirectory(BuildContext context) async {
  if (!(await Permission.storage.request().isGranted)) {
    return Future.error("Storage permission was denied");
  }

  String path = (await getExternalStorageDirectory())!.path;

  var p = Directory(path);
  Directory d = await Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
    return TagTagsFSPickerView(p, p.listSync(), true, []);
  }));

  return d;
}

File genExportFile(Directory dir, String proj) {
  String ts = new DateTime.now().toIso8601String();
  return File(join(dir.path, 'TagTags_${proj}_export_$ts.txt'));
}


/// I originally intended to use a file picker intent, but the packages I found
/// that could handle that caused my SQLite database to become unusable when the
/// app was built for release. I also found that others had the same issue.
/// I thought the simplest solution at that point was to simply implement my own
/// file/dir-picker.
class TagTagsFSPickerView extends StatefulWidget {
  Directory _dir;
  List<FileSystemEntity> _locs;
  List<String> _fileTypes = [];
  bool _pickDir = false;

  TagTagsFSPickerView(this._dir, this._locs, this._pickDir, this._fileTypes) {
    _locs.sort((a, b) => a.path.compareTo(b.path));
  }

  @override
  _TagTagsFSPickerViewState createState() => _TagTagsFSPickerViewState();
}

class _TagTagsFSPickerViewState extends State<TagTagsFSPickerView> {
  Directory _dir = Directory('/');
  List<FileSystemEntity> _locations = [];

  void _navigate(BuildContext c, Directory d) async {
    try {
      _locations = d.listSync();
      _locations.sort((a, b) => a.path.compareTo(b.path));
      _dir = d;
    } on FileSystemException catch (e) {
      noticeDialog(c, 'Access denied', 'Could not open that location: ${e.message}', TagTagsIcons.largeErrorIcon);
      return;
    }

    setState(() {});
  }

  @override
  void initState() {
    _dir = widget._dir;
    _locations = widget._locs;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<ListTile> dirTiles = [];
    List<ListTile> fileTiles = [];

    dirTiles.add(ListTile(
        title: Text(
            '../' + basename(_dir.parent.path) + '/',
            style: TextStyle(
                color: Colors.black
            )
        ),
        leading: TagTagsIcons.goBackIcon,
        onTap: () => _navigate(context, _dir.parent)
    ));

    for (var x = 0; x < _locations.length; x++) {
      var c = _locations[x];

      if (c is File) {
        File f = c;
        String name = basename(f.path);
        String ext = extension(f.path).toLowerCase();
        if(widget._fileTypes.length == 0 || widget._fileTypes.contains(ext)) {
          fileTiles.add(ListTile(
              title: Text(
                  name,
                  style: TextStyle(
                      color: widget._pickDir ? Colors.grey : Colors.black
                  )
              ),
              leading: TagTagsIcons.documentIcon,
              onTap: widget._pickDir ? null : () => Navigator.pop(context, f)
          ));
        }
      } else if (c is Directory) {
        Directory d = c;
        String name = basename(d.path) + '/';
        dirTiles.add(ListTile(
            title: Text(
                name,
                style: TextStyle(
                    color: Colors.black
                )
            ),
            leading: TagTagsIcons.directoryIcon,
            onTap: () => _navigate(context, d),
        ));
      }
    }

    return Scaffold(
        appBar: AppBar(
            title: Text(widget._pickDir ? 'Pick directory' : 'Open file'),
            actions: [
                Visibility(
                    visible: widget._pickDir,
                    child: TextButton(
                        child: Text('Select', style: TextStyle(color: Colors.white)),
                        onPressed: () => Navigator.pop(context, _dir),
                    )
                )
            ]
        ),
        body: ListView(children: [
            Column(mainAxisSize: MainAxisSize.min, children: dirTiles),
            Column(mainAxisSize: MainAxisSize.min, children: fileTiles)
    ]));
  }
}
