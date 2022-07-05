import 'package:flutter/material.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/views/qr-code-reader.dart';
import 'dart:async';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const TEXT_TYPE = 1;

class TagTagsTextWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint))
      _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsTextWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsTextWidgetState createState() => _TagTagsTextWidgetState();
}

class _TagTagsTextWidgetState extends State<TagTagsTextWidget> {
  final textController = TextEditingController();
  var _value = '';
  bool _visible = true;
  bool _highlighted = false;
  Timer? _timer;

  void setValue(String val) {
    widget._setData(widget._data.id, widget._data.type, val, true, widget._data.rememberValues);
    _value = val;
  }

  void update(String val) {
    if (_timer != null) _timer!.cancel();

    _timer = Timer(Duration(milliseconds: _highlighted ? 500 : 200), () {
      setValue(val);
      if (_highlighted) {
        setState(() {
          _highlighted = false;
        });
      }
    });

    _value = val;
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
        widget._value!.typeID == TEXT_TYPE) _value = widget._value!.value;
    else if (_value == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == TEXT_TYPE &&
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

    if (widget._data.mandatory == true &&
        widget._reportMandatoryField != null) {
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

  void _scanBarcode() async {
    String? code;

    try {
      code = await Navigator.of(context)
          .push(MaterialPageRoute(builder: (BuildContext context) {
        return QRCodeReader();
      }));
    } catch(e) {
      noticeDialog(context, "Unexpected error", e.toString(), TagTagsIcons.largeErrorIcon);
    }

    if(code != null) {
      setValue(code);
      setState(() {
        _highlighted = false;
      });
    }
  }

  Widget _barcodeScanner() {
    return IconButton(
      icon: TagTagsIcons.qrCodeIcon,
      onPressed: _scanBarcode,
    );
  }

  @override
  void dispose() {
    textController.dispose();
    if (_timer != null) _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    textController.text = _value;

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
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: textController,
                        onChanged: (String val) {
                          update(val);
                        })),
                if (widget._data.barcode) _barcodeScanner(),
                if (_highlighted) TagTagsIcons.warningIcon
              ]),
            ])));
  }
}
