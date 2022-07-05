import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:tagtags2/base/constants.dart';

import '../alert.dart';


class QRCodeReader extends StatefulWidget {
  @override
  _QRCodeReaderState createState() => _QRCodeReaderState();
}

class _QRCodeReaderState extends State<QRCodeReader> {
  bool cameraAccess = false;
  String? value;

  void _ensureCameraPermission() async {
    if(!(await Permission.camera.request().isGranted)) {
      noticeDialog(context, "Permission error",
          'Without access to the camera TagTags can not scan barcodes', TagTagsIcons.largeErrorIcon);
    } else {
      setState(() {
        cameraAccess = true;
      });
    }
  }

  @override
  initState() {
    super.initState();
    _ensureCameraPermission();
  }

  @override
  Widget build(BuildContext context) {
    if(!cameraAccess) return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black
        ),
      )
    );

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SizedBox(
        height: height,
        width: width,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              height: height,
              width: width,
              child: new QrCamera(
                  onError: (context, error) => Text(
                    error.toString(),
                    style: TextStyle(color: TagTagsColors.primaryColor),
                  ),
                  qrCodeCallback: (code) {
                    setState(() {
                      value = code;
                    });
                  }
              )
            ),
            Positioned(
              top: height/2 - 50,
              left: 0,
              child: SizedBox(
                height: 100,
                width: width,
                child: Text(value != null ? value! : '[No data]', style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                      )
                    ]
                ), textAlign: TextAlign.center,)
              )
            )
          ]
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save),
        onPressed: () => Navigator.of(context).pop(value),
      ),
    );
  }
}
