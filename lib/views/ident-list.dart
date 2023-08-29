import 'package:flutter/material.dart';
import 'package:tagtags2/base/constants.dart';

class TagTagsProtIdentView extends StatelessWidget {
  final List<String> _idents;

  TagTagsProtIdentView(this._idents);

  @override
  Widget build(BuildContext context) {
    void _returnIdent(String ident) {
      Navigator.pop(context, ident);
    }

    return Scaffold(
        appBar: AppBar(
            title: Text('Saved identities')
        ),
        body: Scrollbar(
            thumbVisibility: true,
            thickness: 16,
            child: ListView.builder(
                padding: EdgeInsets.all(10),
                itemCount: _idents.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    title: Text(_idents[i]),
                    trailing: TagTagsIcons.bookmarkIcon,
                    onTap: () => _returnIdent(_idents[i])
                  );
                },
        ))
    );
  }
}
