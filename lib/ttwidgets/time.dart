import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const TIME_TYPE = 5;

class TagTagsTimeWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint)) _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsTimeWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue, this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsTimeWidgetState createState() => _TagTagsTimeWidgetState();
}

class _TagTagsTimeWidgetState extends State<TagTagsTimeWidget> {
  final timeController = TextEditingController();
  var _value = '';
  bool _visible = true;
  bool _highlighted = false;

  void update(val) {
    widget._setData(widget._data.id, widget._data.type, val, true, widget._data.rememberValues);

    setState(() {
      _value = val;
    });
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  void initState() {
    if(_value == '' && widget._value != null && widget._value!.typeID == TIME_TYPE) {
      _value = widget._value!.value;
    } else if (_value == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == TIME_TYPE &&
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
    timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    timeController.text = _value;

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
                        controller: timeController,
                        onTap: () async {
                          var date = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now());

                          update(date.toString().substring(10,15));
                        }
                    )),
                    if(_highlighted) TagTagsIcons.warningIcon
                  ]
                ),
              ]
            )
          ));
  }
}
