import 'database.dart';

class TagTagsSheetDataFormatException implements Exception {
  final String errMsg;

  TagTagsSheetDataFormatException(this.errMsg);
}

class TagTagsSheetData {
  final Map _data;
  final String id;

  final String project;
  final String title;
  final int version;
  late int columns;
  late bool singlePage;
  late TagTagsGroupData identifier;
  late List<TagTagsGroupData> groups = [];

  final Map<String, TagTagsDataPoint> identComps;

  TagTagsSheetData(this.id, this.project, this.title, this.version, this._data, this.identComps) {
    if (!_data.containsKey('columns') || _data['columns'].runtimeType != int)
      throw TagTagsSheetDataFormatException(
          "sheet column count not set or not an integer");

    if (!_data.containsKey('identifier'))
      throw TagTagsSheetDataFormatException(
          "sheet identifier group not defined");

    if (!_data.containsKey('groups'))
      throw TagTagsSheetDataFormatException("sheet has no groups");

    if (_data.containsKey('single_page') && _data['single_page'].runtimeType == bool && _data['single_page'] == true)
      singlePage = true;
    else
      singlePage = false;

    columns = _data['columns'] ?? 1;
    identifier = TagTagsGroupData(_data['identifier'], true);
    for (var x = 0; x < _data['groups'].length; x++)
      groups.add(TagTagsGroupData(_data['groups'][x], false));
  }
}

class TagTagsGroupData {
  final Map _data;

  late String title;
  late String constructor;
  String? description;
  String? visibleIf;
  List<TagTagsFieldData> fields = [];

  TagTagsGroupData(this._data, bool ident) {
    if (!_data.containsKey('title') || _data['title'].runtimeType != String)
      throw TagTagsSheetDataFormatException(
          "group title not set or not a string");

    if (ident &&
        (!_data.containsKey('constructor') ||
            _data['constructor'].runtimeType != String))
      throw TagTagsSheetDataFormatException(
          "identifier group constructor not set or not a string");

    if (!_data.containsKey('fields'))
      throw TagTagsSheetDataFormatException("group has no fields");

    description = _data['description'];
    visibleIf = _data['visible_if'];
    title = _data['title'];
    constructor = _data['constructor'];
    for (var x = 0; x < _data['fields'].length; x++)
      fields.add(TagTagsFieldData(_data['fields'][x]));
  }
}

class TagTagsFieldData {
  final Map _data;

  late String id;
  late String title;
  String? description;
  late bool mandatory;
  late bool allowOther;
  late int type;
  List<String> alternatives = [];
  String? visibleIf;
  String? function;
  bool checkedIsDefault = false;
  bool barcode = false;
  bool rememberValues = false;

  TagTagsFieldData(this._data) {
    if (!_data.containsKey('id') || _data['id'].runtimeType != String)
      throw TagTagsSheetDataFormatException("field id not set or not a string");

    if (!_data.containsKey('title') || _data['title'].runtimeType != String)
      throw TagTagsSheetDataFormatException(
          "field title not set or not a string");

    if (!_data.containsKey('type') || _data['type'].runtimeType != int)
      throw TagTagsSheetDataFormatException(
          "field type not set or not an integer");

    id = _data['id'];
    title = _data['title'];
    description = _data['description'];
    mandatory = _data['mandatory'] ?? false;
    allowOther = _data['allow_other'] ?? false;
    checkedIsDefault = _data['default_checked'] ?? false;
    barcode = _data['barcode'] ?? false;
    type = _data['type'];
    visibleIf = _data['visible_if'];
    function = _data['function'];
    rememberValues = _data['remember_values'] ?? false;

    if (_data.containsKey('alternatives'))
      for (var x = 0; x < _data['alternatives'].length; x++)
        alternatives.add(_data['alternatives'][x].toString());
  }
}
