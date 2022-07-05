import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const DATE_TYPE = 4;

class TagTagsDateWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint)) _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsDateWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue, this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsDateWidgetState createState() => _TagTagsDateWidgetState();
}

class _TagTagsDateWidgetState extends State<TagTagsDateWidget> {
  final dateController = TextEditingController();
  var _value = '';
  bool _visible = true;
  bool _highlighted = false;

  void update(val) {
    widget._setData(widget._data.id, widget._data.type, val, true, widget._data.rememberValues);

    setState(() {
      _highlighted = false;
      _value = val;
    });
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  @override
  void initState() {
    if(_value == '' && widget._value != null && widget._value!.typeID == DATE_TYPE) {
      _value = widget._value!.value;
    } else if (_value == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == DATE_TYPE &&
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
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    dateController.text = _value;

    return Visibility(
          visible: _visible,
          child: Container(
              padding: EdgeInsets.all(2),
              child:Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget._data.title, textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold)),
                  Visibility(
                      visible: widget._data.description != null,
                      child: Text(
                          widget._data.description ?? '',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)
                      )
                  ),
                  Row(
                      children: [
                          Expanded(child: TextField(
                              readOnly: true,
                              controller: dateController,
                              onTap: () async {
                                var date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(1950), lastDate: DateTime(2050));

                                update(date.toString().substring(0,10));
                              }
                          )),
                          if(_highlighted) TagTagsIcons.warningIcon
                      ]),
                ]
              )
            ));
  }
}
