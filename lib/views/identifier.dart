import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/ttwidgets/group.dart';
import 'package:tagtags2/views/collection.dart';
import 'ident-list.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import '../base/expressions.dart';

class TagTagsProtInitView extends StatefulWidget {
  TagTagsDatabase _db;
  String _project;
  String _sheet;

  TagTagsProtInitView(this._db, this._project, this._sheet);

  @override
  _TagTagsProtInitViewState createState() => _TagTagsProtInitViewState();
}

class _TagTagsProtInitViewState extends State<TagTagsProtInitView> {
  late TagTagsSheetData _sheet;
  var _data = new Map<String,TagTagsDataPoint>();
  var _sessionData = new Map<String,TagTagsDataPoint>();
  var _identifier;
  Map<String,List<void Function(String,TagTagsDataPoint)>> dataDependencies = {};

  void _addDataDependency(String key, void Function(String,TagTagsDataPoint) callback) {
    if(!dataDependencies.containsKey(key)) dataDependencies[key] = [];
    dataDependencies[key]!.add(callback);

    if(_data.containsKey(key)) callback(key, _data[key]!);
    else callback(key, TagTagsDataPoint(1, 'NULL'));
  }

  void _updateCallbacks(String key, TagTagsDataPoint dp) {
    if(dataDependencies.containsKey(key)) {
      var dd = dataDependencies[key];
      for(var x = 0; x < dd!.length; x++) {
        dd[x](key, dp);
      }
    }
  }

  late Future<TagTagsSheetData> _futureProt;
  Future<TagTagsSheetData> _getProtData(String project, String id) async {
    return widget._db.getSheet(project, id);
  }

  void _setData(String id, int type, String val, bool persist, bool remember) {
    var dp = TagTagsDataPoint(type, val);
    _data[id] = dp;
    print('$id: $val');

    if(persist == true) widget._db.saveIdentifierComponent(_sheet.id, _sheet.project, id, type, val);

    _identifierUpdate(true);
    _updateCallbacks(id, dp);
  }

  void _setSessionPersistentData(String id, int type, String val) {
    var dp = TagTagsDataPoint(type, val);
    _sessionData[id] = dp;
    print('session data $id: $val');
  }

  void _openCollection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TagTagsProtCollectView(widget._db, _setSessionPersistentData, _sheet, _identifier, _data, _sessionData);
        },
      ),
    );
  }

  Future<void> _openCollectionDestructive() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TagTagsProtCollectView(widget._db, _setSessionPersistentData, _sheet, _sheet.title, _data, _sessionData);
        },
      ),
    );

    Navigator.pop(context, null);
  }

  void _openIdentView() async {
    var idents = await widget._db.getIdentifiers(_sheet.project);

    String? i = await Navigator.of(context).push(
      MaterialPageRoute<String>(
        builder: (BuildContext context) {
          return TagTagsProtIdentView(idents);
        },
      ),
    );

    if(i != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return TagTagsProtCollectView(widget._db, _setSessionPersistentData, _sheet, i, _data, _sessionData);
          },
        ),
      );
    }
  }

  void _identifierUpdate(bool newState) {
    var i;
    try {
      i = TagTagsExpression(_sheet.identifier.constructor, _data).resultToString();
    } catch (e) {
      print(e);
      i = null;
    }

    _identifier = i != 'NULL' ? i : null;

    if(newState && mounted) setState(() { _identifier = i; });
  }

  @override
  void initState() {
    super.initState();
    _futureProt = _getProtData(widget._project, widget._sheet);
  }

  Color _textColor() {
    return _identifier != null ? Colors.white : Colors.grey;
  }

  Color _backgroundColor() {
    return _identifier != null ? TagTagsColors.secondaryColor : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _futureProt,
        builder: (BuildContext context, AsyncSnapshot snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
                decoration: BoxDecoration(
                    color: Colors.white
                ),
                child: Center(
                    child: Image(image: AssetImage('assets/images/tagtags2.png'))
                )
            );
          }

          if (snap.hasData && snap.data != null) {
            _sheet = snap.data;
            _data = _sheet.identComps;
            _identifierUpdate(false);

            if (_sheet.singlePage) {
              WidgetsBinding.instance?.addPostFrameCallback((_) {
                _openCollectionDestructive();
              });

              return Center(
                  child: Text('Redirecting to single-page sheet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
            }

            return Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: Text(_sheet.title),
                  actions: [
                      IconButton(
                          icon: Icon(Icons.list_alt_outlined),
                          onPressed: _openIdentView
                      )
                  ]
                ),
                bottomNavigationBar: Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(color: _backgroundColor(), boxShadow: [
                      BoxShadow(
                        spreadRadius: 2,
                        blurRadius: 3,
                        color: Colors.grey,
                      )
                    ]),
                    child: TextButton(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(_identifier != null
                              ? 'Open collection '
                              : 'Please specify a value in all fields above',
                              style: TextStyle(color: _textColor())),
                            Visibility(
                              visible: _identifier != null,
                              child: Text(
                                  _identifier != null ? _identifier : '',
                                  style: TextStyle(color: _textColor(), fontWeight: FontWeight.bold))
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, color: _textColor())]
                        ),
                        onPressed:
                        _identifier != null ? _openCollection : null)),
                body:  ListView(
                    children: <Widget>[
                        Container(child: _buildFields()),
                    ]
                ));
          }

          return Center(
              child: Text('That sheet does not appear to exist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
        });
  }

  Widget _buildFields() {
    var _group = _sheet.identifier;

    return ListView(
        padding: EdgeInsets.all(10),
        shrinkWrap: true,
        children: [TagTagsGroupWidget(_group, _setData, null, _sheet.identComps, null, _addDataDependency, null)]);
  }
}
