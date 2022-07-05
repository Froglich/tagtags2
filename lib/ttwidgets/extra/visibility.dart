import '../../base/expressions.dart';
import '../../base/database.dart';

class TagTagsVisibilityHandler {
  bool currentState;
  final String? expression;
  final void Function(String, void Function(String, TagTagsDataPoint))
      reportDataDependencyFunc;
  final void Function(bool) setVisFunc;
  Map<String, TagTagsDataPoint> _data = {};

  TagTagsVisibilityHandler(
      {required this.currentState,
      required this.expression,
      required this.reportDataDependencyFunc,
      required this.setVisFunc}) {
    if (expression != null) {
      var v = pVariables.allMatches(expression!);
      v.forEach((m) {
        var n = expression!.substring(m.start + 1, m.end);
        reportDataDependencyFunc(n, (String key, TagTagsDataPoint value) async {
          _data[key] = value;
          bool vis = _shouldBeVisible();
          if (vis != currentState) {
            currentState = vis;
            setVisFunc(vis);
          }
        });
      });
    }
  }

  bool _shouldBeVisible() {
    try {
      if (TagTagsExpression(this.expression, _data).resultToString() == 'TRUE')
        return true;
    } catch (e) {
      print(e);
    }

    return false;
  }
}
