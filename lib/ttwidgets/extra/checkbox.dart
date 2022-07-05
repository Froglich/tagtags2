import 'package:flutter/material.dart';

class TagTagsCheckbox extends StatelessWidget {
  final bool? checked;

  TagTagsCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    var img;
    if (checked == null)
      img = AssetImage('assets/icons/png/checkbox_null.png');
    else if (checked!)
      img = AssetImage('assets/icons/png/checkbox_checked.png');
    else
      img = AssetImage('assets/icons/png/checkbox_unchecked.png');

    return Container(
        child: Center(child: Image(image: img, height: 48, width: 48)));
  }
}
