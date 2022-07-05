import 'package:flutter/material.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import '../base/database.dart';
import '../base/syncing.dart';

class DownloadDetails {
  final TagTagsServer tagTagsServer;
  final Map<String, dynamic> sheetDetails;

  DownloadDetails({required this.tagTagsServer, required this.sheetDetails});
}

class TagTagsDownloadView extends StatefulWidget {
  final TagTagsDatabase _db;

  TagTagsDownloadView(this._db);

  @override
  _TagTagsDownloadViewState createState() =>
      _TagTagsDownloadViewState();
}

class _TagTagsDownloadViewState extends State<TagTagsDownloadView> {
  TagTagsServer? _server;
  List<SheetDetails>? _sheets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Download sheet'),
      ),
      body: Container(child: _buildFields()),
    );
  }

  void _getSheets() async {
    List<SheetDetails> sheets;
    try {
      sheets = await _server!.getSheets();
    } catch (e) {
      noticeDialog(context, 'Server error', e.toString(), TagTagsIcons.largeErrorIcon);
      return;
    }

    setState(() {
      _sheets = sheets;
    });
  }

  void _setServer(s) {
    setState(() {
      _server = s;
    });

    _getSheets();
  }

  void _getSheet(SheetDetails sheet) async {
    Navigator.pop(context, sheet);
  }

  Widget _buildFields() {
    if(_server == null) {
      List<ListTile> tiles = [];

      for(var x = 0; x < widget._db.settings.servers.length; x++) {
        var s = widget._db.settings.servers[x];
        tiles.add(ListTile(
            title: Text('${s.username}@${s.address}', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: TagTagsIcons.serverIcon,
            onTap: () => _setServer(s)
        ));
      }

      return ListView(
          padding: EdgeInsets.all(10),
          children: tiles
      );
    } else if(_sheets == null) {
      return Center(child: CircularProgressIndicator());
    } else {
      List<ListTile> tiles = [];

      for(var x = 0; x < _sheets!.length; x++) {
        var s = _sheets![x];
        tiles.add(ListTile(
          title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(s.name, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Project: ${s.project} & Version: ${s.version}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
              ]
          ),
          leading: TagTagsIcons.documentIcon,
          onTap: () => _getSheet(s)
        ));
      }

      return ListView(
          padding: EdgeInsets.all(10),
          children: tiles
      );
    }
  }
}
