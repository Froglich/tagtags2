import 'package:flutter/material.dart';

Future<bool> approvalDialog(BuildContext context, String title, String q) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext c) {
      return AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Container(
          padding: EdgeInsets.all(5),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text(q)]
          )
        ),
        actions: [
          TextButton(
              onPressed: () { Navigator.pop(c, true); },
              child: Text('Yes')
          ),
          TextButton(
              onPressed: () { Navigator.pop(c, false); },
              child: Text('No')
          )
        ]
      );
    }
  ) ?? false;
}

Future<void> noticeDialog(BuildContext context, String title, String message, Icon icon) async {
  return await showDialog<void>(
    context: context,
    builder: (BuildContext c) {
      return AlertDialog(
          title: Text(title, textAlign: TextAlign.center),
          content: Container(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                        children: [
                            icon,
                            SizedBox(height: 20)
                        ]
                    ),
                    Text(message, textAlign: TextAlign.center)
                ]
            )
        ),
        actions: [
          TextButton(
              onPressed: () { Navigator.pop(c); },
              child: Text('OK')
          ),
        ]
      );
    }
  );
}