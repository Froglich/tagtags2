import 'dart:io';

//import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/base/database.dart';
import '../files.dart';

class TagTagsExportView extends StatefulWidget {
  TagTagsDatabase _db;

  TagTagsExportView(this._db);

  @override
  _TagTagsExportViewState createState() => _TagTagsExportViewState();
}

class _TagTagsExportViewState extends State<TagTagsExportView> {
  String? _selectedValue;
  late Future<List<String>> _futureProjects;

  @override
  void initState() {
    _futureProjects = widget._db.getProjects();
    super.initState();
  }

  void _updateValue(String val) {
    setState(() {
      _selectedValue = val;
    });
  }

  void _exportData() async {
    String p = _selectedValue!;

    Directory d = await pickDirectory(context);
    File f = genExportFile(d, p);
    var data = await widget._db.exportData(p);

    try {
      f.writeAsStringSync(data);
    } on FileSystemException catch(e) {
      noticeDialog(context, 'Could not export data', e.message, TagTagsIcons.largeErrorIcon);
      return;
    } catch(e) {
      noticeDialog(context, 'Could not export data', 'Unexpected error', TagTagsIcons.largeErrorIcon);
      return;
    }

    noticeDialog(context, 'Export complete', 'Data exported as "${getBasename(f.path)}"', TagTagsIcons.largeInfoIcon);
  }

  DropdownButton _buildDropdown(List<String> projects) {
    List<DropdownMenuItem<String>> _menuItems = [];

    for(var x = 0; x < projects.length; x++) {
      _menuItems.add(DropdownMenuItem(
        value: projects[x],
        child: Text(projects[x])
      ));
    }

    return DropdownButton(
        items: _menuItems,
        value: _selectedValue != null ? _selectedValue : null,
        isExpanded: true,
        onChanged: (val) { _updateValue(val); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _futureProjects,
        builder: (BuildContext context, AsyncSnapshot snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          }

          if (snap.hasData && snap.data != null) {
            return Scaffold(
              appBar: AppBar(
                  title: Text('Export data')
              ),
              body: ListView(
                  padding: EdgeInsets.all(20),
                  children: [
                      Text(
                          'Project:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      _buildDropdown(snap.data),
                      SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _selectedValue != null ? _exportData : null,
                          child: Text('Export data')
                      )
                  ]
              )
            );
          }

          return Center(
              child: Text('Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
        });
  }
}