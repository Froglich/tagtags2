import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const SELECT_TYPE = 3;

class TagTagsSelectWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint))
      _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsSelectWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsSelectWidgetState createState() => _TagTagsSelectWidgetState();
}

class _TagTagsSelectWidgetState extends State<TagTagsSelectWidget> {
  FocusNode fNode = FocusNode();
  String _selectedValue = '';
  bool _visible = true;
  bool _highlighted = false;
  final List<DropdownMenuItem<String>> _menuItems = [];

  void updateValue(value) async {
    if(value != '«-|add_new|-»') {
      widget._setData(widget._data.id, widget._data.type, value, true, widget._data.rememberValues);
      fNode.requestFocus();

      setState(() {
        _selectedValue = value;
        _highlighted = false;
      });
    } else {
      String? v = await newValueDialog(context, 'Other value for ${widget._data.title}');

      if (v != null && v != '') {
        widget._data.alternatives.add(v);
        _menuItems.add(DropdownMenuItem(value: v, child: Text(v)));
        widget._setData(widget._data.id, widget._data.type, v, true, widget._data.rememberValues);

        fNode.requestFocus();

        setState(() {
          _selectedValue = v;
          _highlighted = false;
        });
      }
    }
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  @override
  void dispose() {
    fNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (_selectedValue == '' &&
        widget._value != null &&
        widget._value!.typeID == SELECT_TYPE) {
      _selectedValue = widget._value!.value;
    } else if (_selectedValue == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == SELECT_TYPE &&
        widget._setLateData != null) {
      _selectedValue = widget._rememberedValue!.value;
      widget._setLateData!(widget._data.id, widget._data.type, widget._rememberedValue!.value);
    }

    if (_selectedValue != '' &&
        !widget._data.alternatives.contains(_selectedValue)) {
      widget._data.alternatives.add(_selectedValue);
    }

    _menuItems.add(DropdownMenuItem(value: '', child: Text('')));

    for (var x = 0; x < widget._data.alternatives.length; x++) {
      var alt = widget._data.alternatives[x];
      _menuItems.add(DropdownMenuItem(value: alt, child: Text(alt)));
    }

    if (widget._data.allowOther) {
      _menuItems.add(DropdownMenuItem(value: '«-|add_new|-»', child: Text("Other...")));
    }

    super.initState();

    print(widget._data.visibleIf);
    TagTagsVisibilityHandler(
        currentState: _visible,
        expression: widget._data.visibleIf,
        reportDataDependencyFunc: widget._reportDataDependency,
        setVisFunc: setVisibility);

    if (widget._data.mandatory == true &&
        widget._reportMandatoryField != null) {
      widget._reportMandatoryField!(() {
        if (_selectedValue != '' || !_visible) {
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
        child: Container(
            padding: EdgeInsets.all(2),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget._data.title,
                      textAlign: TextAlign.left,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Visibility(
                      visible: widget._data.description != null,
                      child: Text(widget._data.description ?? '',
                          style: TextStyle(
                              fontSize: 11, fontStyle: FontStyle.italic))),
                  Row(children: [
                    Expanded(
                        child: DropdownButton(
                      focusNode: fNode,
                      isExpanded: true,
                      value: _selectedValue,
                      items: _menuItems,
                      onChanged: updateValue,
                    )),
                    if (_highlighted) TagTagsIcons.warningIcon
                  ]),
                ])));
  }
}

Future<String?> newValueDialog(BuildContext context, String title) async {
  String val = '';

  return await showDialog<String>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
            title: Text(title, textAlign: TextAlign.center),
            content: Container(
                padding: EdgeInsets.all(5),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enter a new value:'),
                      TextField(
                        onChanged: (value) {
                          val = value;
                        }
                      )
                    ]
                )
            ),
            actions: [
              TextButton(
                  onPressed: () { Navigator.pop(c, val); },
                  child: Text('Add')
              ),
              TextButton(
                  onPressed: () { Navigator.pop(c, null); },
                  child: Text('Cancel')
              )
            ]
        );
      }
  );
}
