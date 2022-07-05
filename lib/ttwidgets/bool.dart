import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/ttwidgets/extra/checkbox.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const BOOL_TYPE = 6;

class TagTagsBoolWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint))
      _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsBoolWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsBoolWidgetState createState() => _TagTagsBoolWidgetState();
}

class _TagTagsBoolWidgetState extends State<TagTagsBoolWidget> {
  bool? _checked;
  bool _visible = true;
  bool _highlighted = false;

  void update(val) {
    var _v = val ? 'TRUE' : 'FALSE';
    widget._setData(widget._data.id, widget._data.type, _v, true, widget._data.rememberValues);

    print(val);
    setState(() {
      _checked = val;
      _highlighted = false;
    });
  }

  void setVisibility(bool vis) {
    if(mounted) setState(() {
      _visible = vis;
    });
    else _visible = vis;
  }

  @override
  void initState() {
    if (_checked == null &&
        widget._value != null &&
        widget._value!.typeID == BOOL_TYPE)
      _checked = (widget._value!.value == 'TRUE');
    else if (_checked == null && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == BOOL_TYPE &&
        widget._setLateData != null) {
      _checked = (widget._value!.value == 'TRUE');
      widget._setLateData!(widget._data.id, widget._data.type, widget._rememberedValue!.value);
    }
    else if (_checked == null && widget._data.checkedIsDefault) _checked = true;

    super.initState();

    TagTagsVisibilityHandler(
        currentState: _visible,
        expression: widget._data.visibleIf,
        reportDataDependencyFunc: widget._reportDataDependency,
        setVisFunc: setVisibility);

    if (widget._data.mandatory && widget._reportMandatoryField != null) {
      widget._reportMandatoryField!(() {
        if (_checked != null || !_visible) {
          return true;
        } else {
          if (!mounted) return true;
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
        child: InkWell(
            onTap: () => update(_checked != null ? !_checked! : true),
            child: Padding(
                padding: EdgeInsets.fromLTRB(0, 6, 0, 6),
                child: Row(children: [
                  SizedBox(
                      height: 24,
                      width: 24,
                      child: TagTagsCheckbox(checked: _checked)),
                  Expanded(
                      child: Row(children: [
                    SizedBox(width: 5),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(widget._data.title,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Visibility(
                              visible: widget._data.description != null,
                              child: Text(widget._data.description ?? '',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)))
                        ])
                  ])),
                  if (_highlighted) TagTagsIcons.warningIcon
                ]))));
  }
}
