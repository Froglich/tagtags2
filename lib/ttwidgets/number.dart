import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'dart:async';
import '../base/sheet.dart';
import '../base/database.dart';
import 'extra/visibility.dart';

const NUMBER_TYPE = 2;

var pNr = RegExp(r'^\s*\-?[0-9]+(?:\.[0-9]+)?\s*$');

class TagTagsNumberWidget extends StatefulWidget {
  TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint)) _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsNumberWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue, this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsNumberWidgetState createState() => _TagTagsNumberWidgetState();
}

class _TagTagsNumberWidgetState extends State<TagTagsNumberWidget> {
  final numberController = TextEditingController();
  var _value = '';
  bool _visible = true;
  bool _highlighted = false;
  Timer? _timer;

  void _saveValue(val) {
    _value = val;

    if (val == '' || pNr.hasMatch(val)) {
      widget._setData(widget._data.id, widget._data.type, val.trim(), true, widget._data.rememberValues);
      if(_highlighted) setState(() {
        _highlighted = false;
      });
    } else {
      widget._setData(widget._data.id, widget._data.type, '', true, widget._data.rememberValues);
    }
  }

  void update(val) {
    if (_timer != null) _timer!.cancel();
    _timer = Timer(Duration(milliseconds: _highlighted ? 500 : 200), () => {_saveValue(val)});
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  @override
  void initState() {
    if (_value == '' &&
        widget._value != null &&
        widget._value!.typeID == NUMBER_TYPE) _value = widget._value!.value;
    else if (_value == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == NUMBER_TYPE &&
        widget._setLateData != null) {
      _value = widget._rememberedValue!.value;
      widget._setLateData!(widget._data.id, widget._data.type, widget._rememberedValue!.value);
    }

    super.initState();

    TagTagsVisibilityHandler(
        currentState: _visible,
        expression: widget._data.visibleIf,
        reportDataDependencyFunc: widget._reportDataDependency,
        setVisFunc: setVisibility
    );

    if(widget._data.mandatory && widget._reportMandatoryField != null) {
      widget._reportMandatoryField!(() {
        if (_value != '' || !_visible) {
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
    numberController.text = _value;
    numberController.selection = TextSelection.fromPosition(
        TextPosition(offset: numberController.text.length));

    return Visibility(
        visible: _visible,
        child: Container(
            padding: EdgeInsets.all(2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget._data.title,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Visibility(
                  visible: widget._data.description != null,
                  child: Text(
                      widget._data.description ?? '',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)
                  )
              ),
              Row(
                  children: [
                    Expanded(child: TextFormField(
                      controller: numberController,
                      keyboardType: TextInputType.number,
                      onChanged: update,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (val) {
                        if(val == null || !pNr.hasMatch(val)) {
                          return 'Not a number.';
                        } else return null;
                      },
                    )),
                    if(_highlighted) TagTagsIcons.warningIcon
                  ]
              ),
            ])));
  }
}
