import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tagtags2/alert.dart';
import 'package:tagtags2/base/constants.dart';
import 'dart:async';
import '../base/database.dart';
import '../base/sheet.dart';
import 'extra/visibility.dart';

const COORDINATES_TYPE = 7;
final pWKT = RegExp(
    r'POINT ?\((-?[0-9]+(?:\.[0-9]+)?) (-?[0-9]+(?:\.[0-9]+)?) (-?[0-9]+(?:\.[0-9]+)?)\)');

class TagTagsCoordinatesWidget extends StatefulWidget {
  final TagTagsFieldData _data;
  final TagTagsDataPoint? _value;
  final TagTagsDataPoint? _rememberedValue;
  final void Function(String, int, String, bool, bool) _setData;
  void Function(String, int, String)? _setLateData;
  final void Function(String, void Function(String, TagTagsDataPoint))
      _reportDataDependency;
  final void Function(bool Function())? _reportMandatoryField;

  TagTagsCoordinatesWidget(this._data, this._setData, this._setLateData, this._value, this._rememberedValue,
      this._reportDataDependency, this._reportMandatoryField);

  @override
  _TagTagsCoordinatesWidgetState createState() =>
      _TagTagsCoordinatesWidgetState();
}

class _TagTagsCoordinatesWidgetState extends State<TagTagsCoordinatesWidget> {
  double? _lat;
  double? _lon;
  double? _alt;
  bool _visible = true;
  bool _highlighted = false;
  bool _active = false;
  StreamSubscription? ss;

  void update(lat, lon, alt) {
    if (!mounted) return;

    setState(() {
      _lat = lat;
      _lon = lon;
      _alt = alt;
    });
  }

  void setVisibility(bool vis) {
    setState(() {
      _visible = vis;
    });
  }

  void startLocationUpdater() {
    ss = Geolocator.getPositionStream(intervalDuration: Duration(seconds: 1))
        .listen((pos) {
      update(pos.latitude, pos.longitude, pos.altitude);
    });

    setState(() {
      _active = true;
    });
  }

  void stopUpdating() {
    if (ss != null) ss!.cancel();

    if (_lon != null && _lat != null && _alt != null) {
      var val = 'POINT($_lon $_lat $_alt)';
      widget._setData(widget._data.id, widget._data.type, val, true, widget._data.rememberValues);
    }

    setState(() {
      _active = false;
      _highlighted = false;
    });
  }

  void checkPermissionsAndStartUpdating() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      noticeDialog(
          context,
          "No location service",
          "Location services are disabled on this device",
          TagTagsIcons.largeErrorIcon);
      return;
    }

    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) {
        noticeDialog(
            context,
            "Denied access",
            "Access to location services was denied, so TagTags can not update the coordinates.",
            TagTagsIcons.largeErrorIcon);
        return;
      }
    }

    if (p == LocationPermission.deniedForever) {
      noticeDialog(
          context,
          "Permanently denied",
          "Location permissions have been permanently denied, TagTags can no longer request permission.",
          TagTagsIcons.largeErrorIcon);
    }

    startLocationUpdater();
  }

  @override
  void initState() {
    if (widget._value != null && widget._value!.typeID == COORDINATES_TYPE) {
      var m = pWKT.firstMatch(widget._value!.value);
      if (m != null) {
        _lon = double.parse(m.group(1)!);
        _lat = double.parse(m.group(2)!);
        _alt = double.parse(m.group(3)!);
      }
    } else if (widget._rememberedValue != null &&
        widget._rememberedValue!.typeID == COORDINATES_TYPE &&
        widget._setLateData != null) {
      var m = pWKT.firstMatch(widget._rememberedValue!.value);
      if (m != null) {
        _lon = double.parse(m.group(1)!);
        _lat = double.parse(m.group(2)!);
        _alt = double.parse(m.group(3)!);
      }
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
        if ((_lat != null && _lon != null) || !_visible) {
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
    if (ss != null) ss!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: _visible,
        child: Container(
            padding: EdgeInsets.all(2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('φ: ',
                                  style: TextStyle(
                                      fontFamily: 'FiraMono',
                                      fontWeight: FontWeight.bold)),
                              Text('${_lat?.toStringAsFixed(6) ?? '...'}°',
                                  overflow: TextOverflow.ellipsis)
                            ]),
                            Row(children: [
                              Text('λ: ',
                                  style: TextStyle(
                                      fontFamily: 'FiraMono',
                                      fontWeight: FontWeight.bold)),
                              Text('${_lon?.toStringAsFixed(6) ?? '...'}°',
                                  overflow: TextOverflow.ellipsis)
                            ]),
                            Row(children: [
                              Text('a: ',
                                  style: TextStyle(
                                      fontFamily: 'FiraMono',
                                      fontWeight: FontWeight.bold)),
                              Text('${_alt?.toStringAsFixed(1) ?? '...'}m',
                                  overflow: TextOverflow.ellipsis)
                            ])
                          ]),
                      if (_highlighted) TagTagsIcons.warningIcon
                    ]),
                  ])),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    InkWell(
                        child: Container(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                                _active ? Icons.gps_fixed : Icons.gps_off,
                                color: TagTagsColors.secondaryColor)),
                        onTap: !_active
                            ? checkPermissionsAndStartUpdating
                            : stopUpdating),
                    if (_active)
                      SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator())
                  ])
            ])));
  }
}
