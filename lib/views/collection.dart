import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/ttwidgets/group.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import '../base/database.dart';
import '../base/sheet.dart';

class TagTagsProtCollectView extends StatefulWidget {
  TagTagsDatabase _db;
  TagTagsSheetData _sheet;
  String _identifier;
  final Map<String, TagTagsDataPoint> _data;
  final Map<String, TagTagsDataPoint> _sessionData;
  final void Function(String, int, String) _setSessionPersistentData;

  TagTagsProtCollectView(this._db, this._setSessionPersistentData, this._sheet, this._identifier, this._data, this._sessionData);

  @override
  _TagTagsProtCollectViewState createState() => _TagTagsProtCollectViewState();
}

class _TagTagsProtCollectViewState extends State<TagTagsProtCollectView> {
  late Map<String, TagTagsDataPoint> _data;
  late Future<Map<String, TagTagsDataPoint>> _futureData;
  Map<String, TagTagsDataPoint> _lateData = {};
  Map<String,List<void Function(String,TagTagsDataPoint)>> dataDependencies = {};
  List<bool Function()> mandatoryReporters = [];

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

  void _addMandatoryFieldReporter(bool Function() reporter) {
    mandatoryReporters.add(reporter);
  }

  void _setData(String id, int type, String val, bool persist, bool remember) async {
    await _saveLateData();
    var dp = TagTagsDataPoint(type, val);
    _data[id] = dp;
    if(!await widget._db.saveData(widget._sheet.project, widget._identifier, id, type, val, null, false)) {
      noticeDialog(context, "Critical error", "An error occurred when trying to save the following datapoint: [${widget._sheet.project}, ${widget._identifier}, $id] = $val", TagTagsIcons.largeErrorIcon);
    }
    print('$id: $val');
    _updateCallbacks(id, dp);

    if(remember) {
      widget._setSessionPersistentData(id, type, val);
    }
  }

  Future<void> _saveLateData() async {
    for(var k in _lateData.keys) {
      var dp = _lateData[k]!;
      print('SAVE LATE $k: ${dp.value}');
      await widget._db.saveData(widget._sheet.project, widget._identifier, k, dp.typeID, dp.value, null, false);
    }
    _lateData.clear();
  }

  void _setLateData(String id, int type, String val) async {
    var dp = TagTagsDataPoint(type, val);
    _lateData[id] = dp;
    _data[id] = dp;
    print('SET LATE $id: $val');
    _updateCallbacks(id, dp);
  }

  Future<bool> _onWillPop() async {
    bool autoPop = true;
    for(var x = 0; x < mandatoryReporters.length; x++) {
      if(!mandatoryReporters[x]()) {
        autoPop = false;
      }
    }

    if(!autoPop) {
      autoPop = await approvalDialog(context, "Warning", "One or more mandatory fields have not been filled it, continue anyway?");
    }

    return autoPop;
  }

  @override
  void initState() {
    super.initState();
    _data = new Map<String, TagTagsDataPoint>.from(widget._data);

    _futureData =
        widget._db.getIdentifierData(widget._sheet.project, widget._identifier);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _futureData,
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

          if (snap.hasError) {
            return Container(
                color: Colors.white,
                child: Center(
                    child: Column(children: [
                        TagTagsIcons.largeErrorIcon,
                        Text(
                            'An error occurred while reading the sheet: ${snap.error.toString()}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                                fontSize: 20,
                                color: Colors.red))
                ])));
          }

          if (snap.hasData && snap.data != null) {
            _data.addAll(snap.data);

            return WillPopScope(
                onWillPop: _onWillPop,
                child: Scaffold(
                    appBar: AppBar(
                      title: Text(widget._identifier),
                    ),
                    body: SafeArea(
                        child: _buildFields()
                    ),
              ));
          }

          return Container(
              color: Colors.white,
              child: Center(
                  child: Column(children: [
                    TagTagsIcons.largeErrorIcon,
                    Text(
                        'The sheet appears to be completely empty',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                            fontSize: 20,
                            color: TagTagsColors.primaryColor))
                  ])));
        });
  }

  Widget _buildFields() {
    var groups = widget._sheet.groups;
    List<Widget> children = [];

    for (var x = 0; x < groups.length; x++) {
      var group = groups[x];
      children.add(TagTagsGroupWidget(group, _setData, _setLateData, _data, widget._sessionData, _addDataDependency, _addMandatoryFieldReporter));
    }

    int cols = widget._db.settings.columnCount > 0
        ? widget._db.settings.columnCount
        : widget._sheet.columns;

    return WaterfallFlow(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10),
        children: children);
  }
}
