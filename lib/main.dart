// @dart=2.9

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/base/syncing.dart';
import 'package:tagtags2/views/start.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:background_fetch/background_fetch.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Fira font'], await rootBundle.loadString('assets/fira/LICENSE'));
  });

  runApp(Restartable(
    child: TagTags(),
  ));

  BackgroundFetch.registerHeadlessTask(backgroundSyncHeadless);
}

class TagTags extends StatefulWidget {
  @override
  _TagTagsState createState() => _TagTagsState();
}

class _TagTagsState extends State<TagTags> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    int status = await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.ANY
    ), (String taskId) async {  // <-- Event handler
      // This is the fetch-event callback.
      print("[BackgroundFetch] Event received $taskId");
      // IMPORTANT:  You must signal completion of your task or the OS can punish your app
      // for taking too long in the background.
      BackgroundFetch.finish(taskId);
    }, (String taskId) async {  // <-- Task timeout handler.
      // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
      print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
      BackgroundFetch.finish(taskId);
    });
    print('[BackgroundFetch] configure success: $status');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
        fontFamily: 'Fira',
    );

    return MaterialApp(
      title: 'TagTags',
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
            primary: TagTagsColors.primaryColor,
            secondary: TagTagsColors.secondaryColor,
        )
      ),
      home: TagTagsStartView(),
    );
  }
}

class Restartable extends StatefulWidget {
  Restartable({this.child});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartableState>().restart();
  }

  @override
  _RestartableState createState() => _RestartableState();
}

class _RestartableState extends State<Restartable> {
  Key key = UniqueKey();

  void restart() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}