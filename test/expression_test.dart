import 'package:test/test.dart';
import '../lib/base/expressions.dart';

void main() {
  test('Basic expression', () {
    var ex = TagTagsExpression('((560.16*pow(19*1000,-0.072))-273.15)-1.425', {});
    expect(ex.resultToString(), '1.001280536694776');
  });
}

