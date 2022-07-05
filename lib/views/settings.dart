import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:tagtags2/base/constants.dart';
import 'package:tagtags2/main.dart';
import 'package:tagtags2/ttwidgets/extra/checkbox.dart';
import '../base/database.dart';
import '../base/syncing.dart';
import '../alert.dart';

class TagTagsSettingsInitView extends StatefulWidget {
  TagTagsDatabase _db;

  TagTagsSettingsInitView(this._db);

  @override
  _TagTagsSettingsInitViewState createState() =>
      _TagTagsSettingsInitViewState();
}

class _TagTagsSettingsInitViewState extends State<TagTagsSettingsInitView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Container(padding: EdgeInsets.all(10), child: _buildFields()),
    );
  }

  void _showColumnsDialog() async {
    double v = await showDialog<double>(
            context: context,
            builder: (context) => SliderDialog(
                'Set number of columns',
                'Set to 0 to follow the sheet setting.',
                0,
                10,
                10,
                widget._db.settings.columnCount.toDouble())) ??
        0;

    setState(() {
      widget._db.settings.columnCount = v.round();
    });
  }

  void _showServerDialog(TagTagsServer tts) async {
    TagTagsServer? newTTS = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return ServerDialog(tts);
    }));

    if (newTTS != null) await widget._db.saveServer(newTTS);

    setState(() {});
  }

  @override
  void dispose() {
    widget._db.saveSettings();
    super.dispose();
  }

  void _confirmSSLCertificates(bool accept) async {
    bool changedSetting = false;

    if(!accept) {
      changedSetting = true;
    } else {
      changedSetting = await approvalDialog(context, 'Warning', 'Accepting any SSL certificate may potentially make you vulnerable to malicious individuals attempting to acquire your sign-in details. However, if you know that one of your servers is experiencing issues or if you are using a self-signed certificate this is the only way to make downloading and uploading work. Additionally, some devices may erroneously claim that some valid certificates are invalid. Only enable this option if you know what you are doing or if you have been explicitly told to do so by the server administrator. Are you sure you want to accept all SSL certificates?');
    }

    if(changedSetting) {
      widget._db.settings.acceptInvalidSSLCertificates = accept;
      widget._db.saveSettings();
      await noticeDialog(context, 'Restart required', 'TagTags will now restart to implement the SSL certificate change', TagTagsIcons.largeInfoIcon);
      Restartable.restart(context);
    }
  }

  Widget _buildFields() {
    List<Widget> children = [
      SizedBox(
          height: 32,
          child: Center(
              child: Text('Base settings',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
      ListTile(
          title: Text('Automatically synchronize data over a mobile connection'),
          trailing: InkWell(
              onTap: () {
                setState(() {
                  widget._db.settings.syncOverMobile =
                  !widget._db.settings.syncOverMobile;
                });
              },
              child: SizedBox(
                  height: 32,
                  width: 32,
                  child: TagTagsCheckbox(
                    checked: widget._db.settings.syncOverMobile,
                  )))),
      ListTile(
          title: Text('Download images when syncing data'),
          trailing: InkWell(
              onTap: () {
                setState(() {
                  widget._db.settings.downloadImages =
                      !widget._db.settings.downloadImages;
                });
              },
              child: SizedBox(
                  height: 32,
                  width: 32,
                  child: TagTagsCheckbox(
                    checked: widget._db.settings.downloadImages,
                  )))),
      ListTile(
          title: Text('Accept all SSL certificates'),
          trailing: InkWell(
              onTap: () => _confirmSSLCertificates(!widget._db.settings.acceptInvalidSSLCertificates),
              child: SizedBox(
                  height: 32,
                  width: 32,
                  child: TagTagsCheckbox(
                    checked: widget._db.settings.acceptInvalidSSLCertificates,
                  )))),
      ListTile(
          title: Text('Number of columns in sheets'),
          trailing: SizedBox(
            height: 32,
            width: 32,
            child: Center(
                child: Text(widget._db.settings.columnCount.toString(),
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          onTap: _showColumnsDialog),
      SizedBox(
          height: 32,
          child: Center(
              child: Text('Servers',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
    ];

    List<ListTile> serverTiles = [
      ListTile(
          title: Text('Add a new server',
              style: TextStyle(fontStyle: FontStyle.italic)),
          trailing: TagTagsIcons.addIcon,
          onTap: () {
            _showServerDialog(new TagTagsServer.blank());
          })
    ];

    for (var x = 0; x < widget._db.settings.servers.length; x++) {
      TagTagsServer server = widget._db.settings.servers[x];

      serverTiles.add(ListTile(
          title: Text('${server.username}@${server.address}'),
          leading: TagTagsIcons.serverIcon,
          onTap: () {
            _showServerDialog(server);
          }));
    }

    children.add(Expanded(child: ListView(children: serverTiles)));

    return Column(children: children);
  }
}

class SliderDialog extends StatefulWidget {
  final String _title;
  final String _description;
  final double _min;
  final double _max;
  final int _divisions;
  double _value;

  SliderDialog(this._title, this._description, this._min, this._max,
      this._divisions, this._value);

  @override
  _SliderDialogState createState() => _SliderDialogState();
}

class _SliderDialogState extends State<SliderDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(widget._title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Visibility(
              visible: widget._description != '',
              child: Text(widget._description)),
          SizedBox(
              height: 32,
              child: Slider(
                  min: widget._min,
                  max: widget._max,
                  divisions: widget._divisions,
                  label: widget._value.round().toString(),
                  value: widget._value,
                  onChanged: (double v) {
                    setState(() {
                      widget._value = v;
                    });
                  }))
        ]),
        actions: [
          TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context, widget._value);
              })
        ]);
  }
}

class ServerDialog extends StatefulWidget {
  final TagTagsServer _server;
  var _pUrl = RegExp(r'^https?:\/\/[\w\-\_\.]+\.\w+\/?$');

  ServerDialog(this._server);

  @override
  _ServerDialogState createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  var addressController = TextEditingController();
  var usernameController = TextEditingController();
  var passwordController = TextEditingController();

  void _setAddress(String val) {
    if(val.endsWith('/')) val = val.substring(0, val.length - 1);
    widget._server.address = val;
  }

  void _setUsername(String val) {
    widget._server.username = val;
  }

  void _setPassword(String val) {
    widget._server.password = val;
  }

  @override
  void initState() {
    addressController.text = widget._server.address;
    usernameController.text = widget._server.username;
    passwordController.text = widget._server.password;

    super.initState();
  }

  void _deleteSheet() async {
    if (await approvalDialog(context, 'Warning',
            'Are you sure you want to remove this server?') ==
        true) {
      widget._server.delete = true;
      Navigator.pop(context, widget._server);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Server'), actions: [
        Visibility(
            visible: widget._server.id != null,
            child: IconButton(
                icon: Icon(Icons.delete, color: Colors.white),
                onPressed: () => _deleteSheet())),
        IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, widget._server);
            })
      ]),
      body: ListView(padding: EdgeInsets.all(20), children: [
        Container(
            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
            child: Column(children: [
              Text('Address',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextFormField(
                  controller: addressController,
                  onChanged: _setAddress,
                  textAlign: TextAlign.center,
                  autovalidateMode: AutovalidateMode.always,
                  validator: (value) {
                    if (!widget._pUrl.hasMatch(value!)) {
                      return 'This does not look like a valid address.';
                    } else
                      return null;
                  })
            ])),
        Container(
            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
            child: Column(children: [
              Text('Username',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextField(
                controller: usernameController,
                onChanged: _setUsername,
                textAlign: TextAlign.center,
              )
            ])),
        Container(
            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
            child: Column(children: [
              Text('Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextField(
                obscureText: true,
                controller: passwordController,
                onChanged: _setPassword,
                textAlign: TextAlign.center,
              )
            ]))
      ]),
    );
  }
}
