import 'dart:math' as math;

class FormulaEngine {
  final Map<String, Map<String, dynamic>> _published = {};

  FormulaEngine(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if ((row['status'] ?? '').toString() != 'published' || row['active'] == false) continue;
      final key = (row['key'] ?? '').toString();
      if (key.isEmpty) continue;
      final current = _published[key];
      final version = (row['version'] as num?)?.toInt() ?? 1;
      final currentVersion = current == null ? 0 : ((current['version'] as num?)?.toInt() ?? 0);
      if (current == null || version >= currentVersion) _published[key] = Map<String, dynamic>.from(row);
    }
  }

  double? evaluate(String key, Map<String, double> variables, {double? fallback}) {
    final row = _published[key];
    if (row == null) return fallback;
    final expression = (row['expression'] ?? '').toString().trim();
    if (expression.isEmpty) return fallback;
    try {
      final value = FormulaExpressionParser().evaluate(expression, variables);
      final precision = ((row['precision'] as num?)?.toInt() ?? 2).clamp(0, 8);
      final factor = math.pow(10, precision).toDouble();
      return (value * factor).roundToDouble() / factor;
    } catch (_) {
      return fallback;
    }
  }

  List<Map<String, dynamic>> snapshotFor(Iterable<String> keys) {
    final wanted = keys.toSet();
    final out = <Map<String, dynamic>>[];
    for (final entry in _published.entries) {
      if (!wanted.contains(entry.key)) continue;
      final row = entry.value;
      out.add({
        'id': row['id'] ?? '',
        'key': row['key'] ?? '',
        'name': row['name'] ?? '',
        'version': (row['version'] as num?)?.toInt() ?? 1,
        'expression': row['expression'] ?? '',
        'unit': row['unit'] ?? '',
        'precision': (row['precision'] as num?)?.toInt() ?? 2,
        'source': row['source'] ?? '',
        'source_ref': row['source_ref'] ?? '',
        'published_at': row['published_at'],
      });
    }
    out.sort((a, b) => '${a['key']}'.compareTo('${b['key']}'));
    return out;
  }
}

class FormulaExpressionParser {
  late List<_FormulaToken> _tokens;
  int _position = 0;
  late Map<String, double> _variables;

  double evaluate(String expression, Map<String, double> variables) {
    _tokens = _tokenize(expression);
    _position = 0;
    _variables = Map<String, double>.from(variables);
    final value = _parseExpression();
    if (_position != _tokens.length) {
      throw const FormatException('Expressão possui conteúdo inesperado.');
    }
    if (!value.isFinite) throw const FormatException('Resultado não finito.');
    return value;
  }

  List<_FormulaToken> _tokenize(String source) {
    final tokens = <_FormulaToken>[];
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (c.trim().isEmpty) {
        i++;
        continue;
      }
      if ('+-*/^(),'.contains(c)) {
        tokens.add(_FormulaToken(c, c));
        i++;
        continue;
      }
      if (_isDigit(c) || c == '.') {
        var j = i + 1;
        while (j < source.length && (_isDigit(source[j]) || source[j] == '.')) {
          j++;
        }
        final raw = source.substring(i, j);
        if (double.tryParse(raw) == null) throw const FormatException('Número inválido.');
        tokens.add(_FormulaToken('number', raw));
        i = j;
        continue;
      }
      if (_isLetter(c) || c == '_') {
        var j = i + 1;
        while (j < source.length && (_isLetter(source[j]) || _isDigit(source[j]) || source[j] == '_')) {
          j++;
        }
        tokens.add(_FormulaToken('identifier', source.substring(i, j)));
        i = j;
        continue;
      }
      throw FormatException('Caractere não permitido na fórmula: $c');
    }
    return tokens;
  }

  bool _isDigit(String c) => RegExp(r'[0-9]').hasMatch(c);
  bool _isLetter(String c) => RegExp(r'[A-Za-z]').hasMatch(c);
  bool _peek(String type) => _position < _tokens.length && _tokens[_position].type == type;

  _FormulaToken _take(String type) {
    if (!_peek(type)) throw const FormatException('Expressão incompleta.');
    return _tokens[_position++];
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (_peek('+') || _peek('-')) {
      final op = _tokens[_position++].type;
      final right = _parseTerm();
      value = op == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parsePower();
    while (_peek('*') || _peek('/')) {
      final op = _tokens[_position++].type;
      final right = _parsePower();
      if (op == '/' && right.abs() < 1e-12) throw const FormatException('Divisão por zero.');
      value = op == '*' ? value * right : value / right;
    }
    return value;
  }

  double _parsePower() {
    var value = _parseUnary();
    if (_peek('^')) {
      _position++;
      value = math.pow(value, _parsePower()).toDouble();
    }
    return value;
  }

  double _parseUnary() {
    if (_peek('+')) {
      _position++;
      return _parseUnary();
    }
    if (_peek('-')) {
      _position++;
      return -_parseUnary();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    if (_peek('number')) return double.parse(_tokens[_position++].value);
    if (_peek('(')) {
      _position++;
      final value = _parseExpression();
      _take(')');
      return value;
    }
    if (_peek('identifier')) {
      final id = _tokens[_position++].value;
      if (_peek('(')) {
        _position++;
        final args = <double>[];
        if (!_peek(')')) {
          while (true) {
            args.add(_parseExpression());
            if (!_peek(',')) break;
            _position++;
          }
        }
        _take(')');
        return _call(id, args);
      }
      if (id.toLowerCase() == 'pi') return math.pi;
      final value = _variables[id];
      if (value == null) throw FormatException('Variável não informada: $id');
      return value;
    }
    throw const FormatException('Expressão inválida.');
  }

  double _call(String name, List<double> args) {
    switch (name.toLowerCase()) {
      case 'cos':
        if (args.length != 1) throw const FormatException('cos requer 1 argumento.');
        return math.cos(args[0]);
      case 'sin':
        if (args.length != 1) throw const FormatException('sin requer 1 argumento.');
        return math.sin(args[0]);
      case 'tan':
        if (args.length != 1) throw const FormatException('tan requer 1 argumento.');
        return math.tan(args[0]);
      case 'sqrt':
        if (args.length != 1 || args[0] < 0) throw const FormatException('sqrt inválido.');
        return math.sqrt(args[0]);
      case 'abs':
        if (args.length != 1) throw const FormatException('abs requer 1 argumento.');
        return args[0].abs();
      case 'min':
        if (args.isEmpty) throw const FormatException('min requer argumento.');
        return args.reduce((a, b) => a < b ? a : b);
      case 'max':
        if (args.isEmpty) throw const FormatException('max requer argumento.');
        return args.reduce((a, b) => a > b ? a : b);
      default:
        throw FormatException('Função não permitida: $name');
    }
  }
}

class _FormulaToken {
  final String type;
  final String value;
  const _FormulaToken(this.type, this.value);
}
