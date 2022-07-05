import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TagTagsColors {
  static Color primaryColor = Color(0xffAA0014);
  static Color secondaryColor = Color(0xff004B0D);
}

class TagTagsIcons {
  static Icon downloadIcon =
      Icon(Icons.download_outlined, color: TagTagsColors.secondaryColor);
  static Icon syncIcon = Icon(Icons.sync, color: TagTagsColors.secondaryColor);
  static Icon directoryIcon =
      Icon(Icons.folder_open, color: TagTagsColors.secondaryColor);
  static Icon exportIcon =
      Icon(Icons.save, color: TagTagsColors.secondaryColor);
  static Icon documentIcon =
      Icon(Icons.insert_drive_file, color: TagTagsColors.secondaryColor);
  static Icon warningIcon =
      Icon(Icons.warning_rounded, color: TagTagsColors.primaryColor);
  static Icon qrCodeIcon = Icon(Icons.qr_code, color: TagTagsColors.primaryColor);
  static Icon goBackIcon =
      Icon(Icons.arrow_back, color: TagTagsColors.primaryColor);
  static Icon serverIcon =
      Icon(Icons.mediation_rounded, color: TagTagsColors.secondaryColor);
  static Icon bookmarkIcon =
      Icon(Icons.bookmark, color: TagTagsColors.secondaryColor);
  static Icon addIcon =
      Icon(Icons.add_box_rounded, color: TagTagsColors.secondaryColor);
  static Icon errorIcon = Icon(Icons.error, color: TagTagsColors.primaryColor);
  static Icon infoIcon =
      Icon(Icons.info_outline_rounded, color: TagTagsColors.secondaryColor);
  static Icon largeErrorIcon =
      Icon(Icons.error, color: TagTagsColors.primaryColor, size: 48);
  static Icon largeInfoIcon = Icon(Icons.info_outline_rounded,
      color: TagTagsColors.secondaryColor, size: 48);
}
