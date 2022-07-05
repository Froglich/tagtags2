import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import '../base/expressions.dart';
import 'extra/visibility.dart';

const FUNCTION_TYPE = 10;

class TagTagsFunctionWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint)) _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsFunctionWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsFunctionWidgetState createState() =>
      _TagTagsFunctionWidgetState();
}

class _TagTagsFunctionWidgetState extends State<TagTagsFunctionWidget> {
  var _value = 'NULL';
  bool _visible = true;
  bool _highlighted = false;
  String _errMsg = '';
  Map<String,TagTagsDataPoint> _data = {};

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  void update() {
    String val = 'NULL';
    try {
      val = TagTagsExpression(widget._data.function, _data).resultToString();
      _errMsg = '';
    } catch(e) {
      _errMsg = 'The function failed to run.';
    }

    if(val != 'NULL' && val != _value) widget._setData(widget._data.id, widget._data.type, val, true, widget._data.rememberValues);
    else if(val == 'NULL' && val != _value) widget._setData(widget._data.id, widget._data.type, '', true, widget._data.rememberValues);

    setState(() {
      _value = val;
      _highlighted = false;
    });
  }

  @override
  void initState() {
    if (_value == 'NULL' &&
        widget._value != null &&
        widget._value!.typeID == FUNCTION_TYPE) _value = widget._value!.value;
    else if (_value == 'NULL' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == FUNCTION_TYPE &&
        widget._setLateData != null) {
      _value = widget._rememberedValue!.value;
      widget._setLateData!(widget._data.id, widget._data.type, widget._rememberedValue!.value);
    }

    super.initState();

    TagTagsVisibilityHandler(
        currentState: _visible,
        expression: widget._data.visibleIf,
        reportDataDependencyFunc: widget._reportDataDependency,
        setVisFunc: setVisibility);
    
    if(widget._data.function == null) {
      _errMsg = 'No function set.';
    } else {
      var v = pVariables.allMatches(widget._data.function!);
      v.forEach((m) {
        var n = widget._data.function!.substring(m.start + 1, m.end);
        widget._reportDataDependency(n, (String key, TagTagsDataPoint value) {
          _data[key] = value;
          update();
        });
      });
    }

    if (widget._data.mandatory == true &&
        widget._reportMandatoryField != null) {
      widget._reportMandatoryField!(() {
        if (_value != 'NULL' || !_visible) {
          return true;
        } else {
          if(!mounted) return true;
          setState(() {
            _highlighted = true;
          });
          return false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: _visible,
        child: Container(
            padding: EdgeInsets.all(2),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget._data.title,
                        textAlign: TextAlign.left,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Visibility(
                        visible: widget._data.description != null,
                        child: Text(
                            widget._data.description ?? '',
                            style: TextStyle(
                                fontSize: 11, fontStyle: FontStyle.italic))),
                    Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if(_errMsg == '') Icon(Icons.functions, color: TagTagsColors.secondaryColor),
                          if(_errMsg == '') Text('= '),
                          if(_errMsg == '') Text(_value),
                          if(_errMsg != '') Icon(Icons.error, color: TagTagsColors.primaryColor),
                          if(_errMsg != '') Flexible(child: Text(_errMsg, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: TagTagsColors.primaryColor))),
                          if (_highlighted) TagTagsIcons.warningIcon
                    ]),
                  ])));
  }
}
