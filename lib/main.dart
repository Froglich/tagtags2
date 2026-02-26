import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/views/start.dart';
import 'package:flutter/services.dart' show rootBundle;
//import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  //sqfliteFfiInit();
  //databaseFactory = databaseFactoryFfi;

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Fira font'], await rootBundle.loadString('assets/fira/LICENSE'));
  });

  runApp(Restartable(
    child: TagTags(),
  ));
}

class TagTags extends StatefulWidget {
  @override
  _TagTagsState createState() => _TagTagsState();
}

class _TagTagsState extends State<TagTags> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
        fontFamily: 'Fira',
    );

    return MaterialApp(
      title: 'TagTags',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Fira',
        colorScheme: ColorScheme.fromSeed(
          seedColor: TagTagsColors.primaryColor,
          primary: TagTagsColors.primaryColor,
          secondary: TagTagsColors.secondaryColor,
          // FORCING WHITE BACKGROUNDS:
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: TagTagsColors.primaryColor,
          foregroundColor: Colors.white, // Text/Icon color
        ),
      ),
      home: TagTagsStartView(),
    );
  }
}

class Restartable extends StatefulWidget {
  Restartable({required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartableState>()!.restart();
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