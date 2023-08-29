import 'dart:math';
import 'package:tagtags2/base/database.dart';

final pNr = RegExp(r'^\-?[0-9]+(?:\.[0-9]+)?$');
final pBool = RegExp(r'^(TRUE|FALSE)$');
final pString = RegExp(r'^`.*`$');
final pVariables = RegExp(r'\$[\w_]+');
final pFunction = RegExp(r'[\w]+\(.+?\)');
final pParentheses = RegExp(r'\([0-9\.\^\*\/\-\+]+\)');

/// Regular expressions for finding "simple" operations, in the order the
/// operations should be performed.
final pSimpleOperations = [
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(\*) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(\/) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(\+) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(\-) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(%) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(<) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(>) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(<=) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(
      r'(?<![\"`]) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(>=) *(\-?[0-9]+(?:\.[0-9]+)?|NULL) *(?![\"`])'),
  RegExp(r' *([\w+\-."\\\/_ `]+) *(=) *([\w+\-."\\\/_ `]+) *'),
  RegExp(r' *([\w+\-."\\\/_ `]+) *(!=) *([\w+\-."\\\/_ `]+) *')
];

class TagTagsExpression {
  var _expression;
  Map<String, TagTagsDataPoint> _variables;
  var _result;

  TagTagsExpression(this._expression, this._variables) {
    var v = pVariables.firstMatch(_expression);

    var origExpression = this._expression;

    while (v != null) {
      var _v = _expression.substring(v.start, v.end);
      var _k = _v.substring(1);

      if (_variables.containsKey(_k) && _variables[_k]!.value != '') {
        String val = _variables[_k]!.value;

        var isNum = pNr.hasMatch(val);

        if (!isNum) {
          val = val.replaceAll('-', '&hyphen;');
        }

        if(!isNum && !pBool.hasMatch(val) && val != 'NULL') {
          val = '`$val`';
        }

        _expression = _expression.replaceAll(
            _v,
            val.replaceAll('+', '&plus;')
               .replaceAll('/', '&sol;')
               .replaceAll('*', '&ast;')
               .replaceAll('<', '&#060;')
               .replaceAll('>', '&#062;')
               .replaceAll('(', '&lpar;')
               .replaceAll(')', '&rpar;')
               .replaceAll('%', '&percnt;')
               .replaceAll('=', '&equals;')
               .replaceAll('\$', '&#36;'));
      } else
        _expression = _expression.replaceAll(_v, 'NULL');

      v = pVariables.firstMatch(_expression);
    }

    _result = _unEncloseString(_solve(_expression.trim())
        .replaceAll('"', '')
        .replaceAll('&hyphen;', '-')
        .replaceAll('&plus;', '+')
        .replaceAll('&sol;', '/')
        .replaceAll('&ast;', '*')
        .replaceAll('&#060;', '<')
        .replaceAll('&#062;', '>')
        .replaceAll('&lpar;', '(')
        .replaceAll('&rpar;', ')')
        .replaceAll('&percnt;', '%')
        .replaceAll('&equals;', '=')
        .replaceAll('&#36;', '\$'));

    print('$origExpression solves to $_result');
  }

  String _unEncloseString(String input) {
    if(pString.hasMatch(input)) {
      return input.substring(1, input.length-1);
    }

    return input;
  }

  String _combine(a, o, b) {
    if ((a == 'NULL' || b == 'NULL') && !['=', '!='].contains(o)) return 'NULL';

    if (['*', '/', '+', '-', '<', '>', '<=', '>=', '%'].contains(o)) {
      var _a = num.parse(a);
      var _b = num.parse(b);

      switch (o) {
        case '*':
          return (_a * _b).toString();
        case '/':
          return (_a / _b).toString();
        case '+':
          return (_a + _b).toString();
        case '-':
          return (_a - _b).toString();
        case '%':
          return (_a % _b).toString();
        case '<':
          return _a < _b ? 'TRUE' : 'FALSE';
        case '>':
          return _a > _b ? 'TRUE' : 'FALSE';
        case '<=':
          return _a <= _b ? 'TRUE' : 'FALSE';
        case '>=':
          return _a >= _b ? 'TRUE' : 'FALSE';
      }
    } else if (o == '=') {
      return _unEncloseString(a) == _unEncloseString(b) ? 'TRUE' : 'FALSE';
    } else if (o == '!=') {
      return _unEncloseString(a) != _unEncloseString(b) ? 'TRUE' : 'FALSE';
    }

    return "";
  }

  String _allAreTrue(List<String> comps) {
    for (var x = 0; x < comps.length; x++) {
      if (comps[x] != 'TRUE') {
        return 'FALSE';
      }
    }

    return 'TRUE';
  }

  String _oneIsTrue(List<String> comps) {
    return comps.contains('TRUE') ? 'TRUE' : 'FALSE';
  }

  String _coalesce(List<String> comps) {
    for (var x = 0; x < comps.length; x++) {
      if (comps[x] != 'NULL') {
        if(!pNr.hasMatch(comps[x]) && !pBool.hasMatch(comps[x]))
          return '`${comps[x]}`';
        else
          return comps[x];
      }
    }

    return 'NULL';
  }

  String _switch(List<String> comps) {
    if(comps.length < 2) {
      return 'NULL';
    }

    String compareTo = comps[0];
    var maxX = comps.length-1;
    for(var x = 1; x <= maxX; x++){
      var comp = comps[x].split(':');
      if(x == maxX && comp.length == 1) return comp[0].trim();
      else if(comp.length < 2) return 'NULL';
      else if(_unEncloseString(comp[0].trim()) == compareTo) return comp[1].trim();
    }

    return 'NULL';
  }

  String _contains(String subject, String child) {
    return subject.contains(child) ? 'TRUE' : 'FALSE';
  }

  String _endsWith(String subject, String child) {
    return subject.endsWith(child) ? 'TRUE' : 'FALSE';
  }

  String _startsWith(String subject, String child) {
    return subject.startsWith(child) ? 'TRUE' : 'FALSE';
  }

  String _index(String subject, String child) {
    return subject.indexOf(child).toString();
  }

  String _lcase(String input) {
    return '`${input.toLowerCase()}`';
  }

  String _ucase(String input) {
    return '`${input.toUpperCase()}`';
  }

  String _solveFunction(s) {
    /// The regular expression is not clever enough to find both the start and
    /// end of functions that are nested, therefore we instead just find the
    /// beginning of top-level expressions and then walk through them one
    /// character at a time until we find the closing parenthesis.
    var match = pFunction.firstMatch(s);
    while (match != null) {
      var substr = s.substring(match.start);
      var start = substr.indexOf('(') + 1;

      var openP = 1;
      var step = 0;
      while (openP > 0) {
        if (substr[start + step] == ')')
          openP--;
        else if (substr[start + step] == '(') openP++;

        step++;
      }
      var end = start + step - 1;
      var fString = substr.substring(0, end + 1); //complete function call
      var fName = substr.substring(0, start - 1); //name of the function
      var fArgs = substr.substring(start, end); //arguments in the function

      fArgs = _solve(fArgs); //solve all nested functions/operations first
      var args = fArgs.split(',');
      var result = "";

      for (var x = 0; x < args.length; x++) {
        args[x] = _unEncloseString(args[x].trim());
      }

      switch (fName) {
        case 'abs':
          result = !args.contains('NULL')
              ? num.parse(args[0]).abs().toString()
              : 'NULL';
          break;
        case 'pow':
          result = !args.contains('NULL')
              ? (pow(num.parse(args[0]), num.parse(args[1]))).toString()
              : 'NULL';
          break;
        case 'sqrt':
          result = args[0] != 'NULL'
              ? (sqrt(num.parse(args[0]))).toString()
              : 'NULL';
          break;
        case 'sin':
          result =
              args[0] != 'NULL' ? (sin(num.parse(args[0]))).toString() : 'NULL';
          break;
        case 'cos':
          result =
              args[0] != 'NULL' ? (cos(num.parse(args[0]))).toString() : 'NULL';
          break;
        case 'tan':
          result =
              args[0] != 'NULL' ? (tan(num.parse(args[0]))).toString() : 'NULL';
          break;
        case 'asin':
          result = args[0] != 'NULL'
              ? (asin(num.parse(args[0]))).toString()
              : 'NULL';
          break;
        case 'acos':
          result = args[0] != 'NULL'
              ? (acos(num.parse(args[0]))).toString()
              : 'NULL';
          break;
        case 'atan':
          result = args[0] != 'NULL'
              ? (atan(num.parse(args[0]))).toString()
              : 'NULL';
          break;
        case 'coalesce':
          result = _coalesce(args);
          break;
        case 'round':
          result = num.parse(args[0]).toStringAsFixed(int.parse(args[1]));
          break;
        case 'length':
          result = args[0] != 'NULL' ? args[0].length.toString() : 'NULL';
          break;
        case 'concat':
          result = !args.contains('NULL') ? '`${args.join('')}`' : 'NULL';
          break;
        case 'right':
          result = !args.contains('NULL')
              ? '`${args[0].substring(args[0].length - int.tryParse(args[1]))}`'
              : 'NULL';
          break;
        case 'left':
          result = !args.contains('NULL')
              ? '`${args[0].substring(0, int.tryParse(args[1]))}`'
              : 'NULL';
          break;
        case 'and':
          result = _allAreTrue(args);
          break;
        case 'or':
          result = _oneIsTrue(args);
          break;
        case 'contains':
          result = !args.contains('NULL') ? _contains(args[0], args[1]) : 'NULL';
          break;
        case 'startswith':
          result = !args.contains('NULL') ? _startsWith(args[0], args[1]) : 'NULL';
          break;
        case 'endswith':
          result = !args.contains('NULL') ? _endsWith(args[0], args[1]) : 'NULL';
          break;
        case 'index':
          result = !args.contains('NULL') ? _index(args[0], args[1]) : 'NULL';
          break;
        case 'lcase':
          result = args[0] != 'NULL' ? _lcase(args[0]) : 'NULL';
          break;
        case 'ucase':
          result = args[0] != 'NULL' ? _ucase(args[0]) : 'NULL';
          break;
        case 'switch':
          result = _switch(args);
          break;
        case 'if':
          if (args[0] == 'TRUE')
            result = args[1];
          else
            result = args[2];
          break;
      }

      s = s.replaceAll(fString, result);
      match = pFunction.firstMatch(s);
    }

    return s;
  }

  String _solve(s) {
    //first solve any function calls, nested operations call back to _solve
    s = _solveFunction(s);

    //then solve any parentheses
    var parenthesis = pParentheses.firstMatch(s);
    while (parenthesis != null) {
      var p = s.substring(parenthesis.start, parenthesis.end);
      s = s.replaceAll(p, _solve(p.substring(1, p.length - 1)));
      parenthesis = pParentheses.firstMatch(s);
    }

    //finally perform all "simple" operations in the proper order
    for (var pSimpleOperation in pSimpleOperations) {
      var operation = pSimpleOperation.firstMatch(s);
      while (operation != null) {
        var res = _combine(operation.group(1), operation.group(2), operation.group(3));
        s = s.substring(0, operation.start) + res + s.substring(operation.end);
        operation = pSimpleOperation.firstMatch(s);
      }
    }

    return s;
  }

  String resultToString() {
    return _result;
  }
}
