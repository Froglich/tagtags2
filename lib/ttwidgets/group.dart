import 'package:flutter/material.dart';
import 'package:tagtags2/ttwidgets/coordinates.dart';
import 'package:tagtags2/ttwidgets/function.dart';
import 'extra/default.dart';
import 'text.dart';
import 'number.dart';
import 'select.dart';
import 'date.dart';
import 'time.dart';
import 'bool.dart';
import 'camera.dart';
import 'extra/visibility.dart';
import '../base/database.dart';
import '../base/sheet.dart';

class TagTagsGroupWidget extends StatefulWidget {
  final TagTagsGroupData _group;
  final Map<String,TagTagsDataPoint> _data;
  final Map<String,TagTagsDataPoint>? _sessionData;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint)) _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsGroupWidget(this._group, this._setData, this._setLateData, this._data, this._sessionData, this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsGroupWidgetState createState() => _TagTagsGroupWidgetState();
}

class _TagTagsGroupWidgetState extends State<TagTagsGroupWidget> {
  bool _visible = true;

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  @override
  void initState() {
    super.initState();

    TagTagsVisibilityHandler(
        currentState: _visible,
        expression: widget._group.visibleIf,
        reportDataDependencyFunc: widget._reportDataDependency,
        setVisFunc: setVisibility
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [Text(widget._group.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))];

    if(widget._group.description != null) {
      children.add(Text(widget._group.description!, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 11, fontStyle: FontStyle.italic)));
    }

    for(var x = 0; x < widget._group.fields.length; x++) {
      var field = widget._group.fields[x];
      var ttw;
      TagTagsDataPoint? value = widget._data.containsKey(field.id) ? widget._data[field.id] : null;
      TagTagsDataPoint? rememberedValue;
      if(field.rememberValues && widget._sessionData != null) {
        rememberedValue = widget._sessionData![field.id];
      }

      switch(field.type) {
        case NUMBER_TYPE:
          ttw = TagTagsNumberWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case SELECT_TYPE:
          ttw = TagTagsSelectWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case DATE_TYPE:
          ttw = TagTagsDateWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case TIME_TYPE:
          ttw = TagTagsTimeWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case BOOL_TYPE:
          ttw = TagTagsBoolWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case COORDINATES_TYPE:
          ttw = TagTagsCoordinatesWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case CAMERA_TYPE:
          ttw = TagTagsCameraWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case FUNCTION_TYPE:
          ttw = TagTagsFunctionWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
          break;
        case TEXT_TYPE:
        default:
          ttw = TagTagsTextWidget(field, widget._setData, widget._setLateData, value, rememberedValue, widget._reportDataDependency, widget._reportMandatoryField);
      }

      children.add(ttw);
    }

    return Visibility(
        visible: _visible,
        child: defaultContainer(Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
          )
        )
    );
  }
}
