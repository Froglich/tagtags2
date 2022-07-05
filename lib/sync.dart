import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/base/database.dart';

class TagTagsSyncWidget extends StatefulWidget {
  final TagTagsDatabase _db;
  final void Function(List<String> errors) _syncComplete;

  TagTagsSyncWidget(this._db, this._syncComplete);

  @override
  _TagTagsSyncWidgetState createState() => _TagTagsSyncWidgetState();
}

class _TagTagsSyncWidgetState extends State<TagTagsSyncWidget> {
  String _syncMessage = '';
  List<String> errors = [];
  double progress = 0;

  Icon syncIcon = TagTagsIcons.syncIcon;
  
  void showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: TagTagsColors.primaryColor));
    setState(() {
      syncIcon = TagTagsIcons.errorIcon;
    });
  }
  
  void sync() async {
    List<String> projs = await widget._db.getSyncableProjects();

    for (var x = 0; x < projs.length; x++) {
      var proj = projs[x];
      double cdt = widget._db.getCurrentTime();
      setState(() {
        progress = 0;
        _syncMessage = 'Uploading "$proj"-data...';
      });

      var tts = await widget._db.getProjectServer(proj);
      try {
        await tts.uploadData(widget._db, proj);
      } catch(e) {
        showSnackBar("The data for project '$proj' could not be uploaded: $e");
        continue;
      }

      setState(() {
        _syncMessage = 'Uploading "$proj"-files...';
      });

      var dataSet = await widget._db.getUnsyncedComplexData(proj);
      for(var i = 0; i < dataSet.data.length; i++) {
        try {
          await tts.uploadBinaryData(dataSet.data[i]);
          await widget._db.setDataPointSynced(dataSet.data[i]);
        } catch(e) {
          showSnackBar(e.toString());
        }

        setState(() {
          progress = i / dataSet.data.length.toDouble();
        });
      }

      setState(() {
        _syncMessage = 'Downloading "$proj"-data...';
      });

      double mostRecentSyncTime =
          await widget._db.getMostRecentSyncTime(proj);
      List<dynamic> dc = await tts.downloadData(proj, mostRecentSyncTime);

      setState(() {
        _syncMessage = 'Persisting "$proj"-data...';
        progress = 0;
      });

      for (var y = 0; y < dc.length; y++) {
        var dp = dc[y];
        await widget._db.saveData(
            dp['project'],
            dp['identifier'],
            dp['parameter'],
            dp['type_id'],
            dp['value'],
            dp['modified'].toDouble(),
            true);

        setState(() {
          progress = y / dc.length.toDouble();
        });
      }
      
      if(widget._db.settings.downloadImages) {
        setState(() {
          _syncMessage = 'Downloading missing files...';
          progress = 0;
        });
        
        var files = await widget._db.getMissingComplexData(proj);;

        for(var i = 0; i < files.length; i++) {
          var fname = files[i];
          print(fname);

          setState(() {
            progress = i / files.length.toDouble();
          });

          try {
            await tts.downloadFile(proj, fname);
          } catch(e) {
            showSnackBar(e.toString());
          }
        }

      }

      await widget._db.insertNewSyncTime(proj, cdt, true);
    }

    widget._syncComplete(errors);
  }

  @override
  Widget build(BuildContext context) {
    if (_syncMessage == '') {
      sync();
      return Container();
    }

    return Expanded(
        child: Container(
            padding: EdgeInsets.fromLTRB(10, 10, 0, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Expanded(child: Text(_syncMessage)),
                      Expanded(child: Container()),
                      LinearProgressIndicator(value: progress > 0 ? progress : null)
                    ])),
                Container(
                    padding: EdgeInsets.all(10),
                    child: Center(
                        child: syncIcon
                    )
                )
              ],
            )));
  }
}
