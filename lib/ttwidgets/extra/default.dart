import 'package:flutter/material.dart';

Widget defaultContainer(child) {
  return Container(
      padding: EdgeInsets.all(0),
      child: PhysicalModel(
          color: Colors.black,
          elevation: 4,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
                //border: Border.all(color: Colors.grey, width: 1, style: BorderStyle.solid),
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(8))),
            child: child,
          )));
}
