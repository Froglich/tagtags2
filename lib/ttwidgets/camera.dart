import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const CAMERA_TYPE = 8;

class TagTagsCameraWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint))
      _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsCameraWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsCameraWidgetState createState() => _TagTagsCameraWidgetState();
}

class _TagTagsCameraWidgetState extends State<TagTagsCameraWidget> {
  var _value = '';
  File? _image;
  Directory? path;
  bool _visible = true;
  bool _highlighted = false;
  final picker = ImagePicker();

  Future<File> move(File source, String newPath) async {
    /*if (!(await Permission.accessMediaLocation.request().isGranted)) {
      return Future.error("Permission to access device storage not granted.");
    }*/

    if (_image != null) await _image!.delete();

    try {
      File target = File(newPath);
      target.writeAsBytesSync(source.readAsBytesSync());

      return target;
      //return await source.rename(newPath);
    } on FileSystemException catch (e) {
      var newFile = await source.copy(newPath);
      await source.delete();
      return newFile;
    }
  }

  void initialize() async {
    path = await getApplicationDocumentsDirectory();

    if (_value != '') {
      setState(() {
        _image = File(join(path!.path, _value));
      });
    }
  }

  void saveImage(BuildContext context, File f) async {
    path = await getApplicationDocumentsDirectory();
    String fname =
        'TT_${widget._data.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    String newPath = join(path!.path, fname);

    try {
      _image = await move(f, newPath);
      _value = fname;

      widget._setData(widget._data.id, widget._data.type, fname, true, widget._data.rememberValues);
      setState(() {});
    } catch (e) {
      noticeDialog(context, "Unexpected error",
          "Unable to save the image file: $e", TagTagsIcons.largeErrorIcon);
    }
  }

  void pickImage(BuildContext context) async {
    PickedFile? f;
    try {
      f = await picker.getImage(source: ImageSource.camera);
    } on PlatformException catch (e) {
      noticeDialog(context, "Platform error", "Probably missing permission to open camera. Error: $e",
          TagTagsIcons.largeErrorIcon);
    } catch(e) {
      noticeDialog(context, "Unexpected error", "Unable to open camera: $e",
          TagTagsIcons.largeErrorIcon);
    }

    if (f != null) saveImage(context, File(f.path));
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  Widget buildImage(BuildContext context) {
    Widget w;

    if (_image == null) {
      w = Container(
          padding: EdgeInsets.all(20),
          child: Icon(Icons.camera,
              color: TagTagsColors.secondaryColor, size: 48));
    } else if (!_image!.existsSync()) {
      w = Container(
          padding: EdgeInsets.all(5),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(
                    'Image data exists, but the image is not available on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TagTagsColors.secondaryColor))),
            Container(
                padding: EdgeInsets.all(15),
                child: Icon(Icons.image_not_supported_rounded,
                    color: TagTagsColors.secondaryColor, size: 48))
          ]));
    } else {
      try {
        w = Image.file(_image!, fit: BoxFit.fill);
      } catch (e) {
        print(e);
        w = Container(
            padding: EdgeInsets.all(5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text('Could not load image: $e',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TagTagsColors.primaryColor))),
              Container(
                  padding: EdgeInsets.all(15),
                  child: TagTagsIcons.largeErrorIcon)
            ]));
      }
    }

    return InkWell(
        child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: TagTagsColors.secondaryColor,
                  width: 2,
                  style: BorderStyle.solid),
            ),
            child: w),
        onTap: () => pickImage(context));
  }

  @override
  void initState() {
    if (_value == '' &&
        widget._value != null &&
        widget._value!.typeID == CAMERA_TYPE) _value = widget._value!.value;
    else if (_value == '' && widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == CAMERA_TYPE &&
        widget._setLateData != null) {
      _value = widget._rememberedValue!.value;
      widget._setLateData!(widget._data.id, widget._data.type, widget._rememberedValue!.value);
    }

    super.initState();

    initialize();

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
                  child: Text(widget._data.description ?? '',
                      style: TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic))),
              Row(children: [
                Expanded(child: buildImage(context)),
                if (_highlighted) TagTagsIcons.warningIcon
              ]),
            ])));
  }
}
