import 'dart:ui';

final RegExp _pathTokenPattern = RegExp(
  r'[MmLlHhVvCcAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
);
final RegExp _separatorPattern = RegExp(r'^[\s,]*$');
final RegExp _commandPattern = RegExp(r'^[MmLlHhVvCcAaZz]$');

const int _coordinateCount = 2;
const int _curveNumberCount = 6;
const int _arcNumberCount = 7;

List<String> tokenizeIconPath(String pathData) {
  final List<String> tokens = <String>[];
  int consumedUntil = 0;

  for (final RegExpMatch match in _pathTokenPattern.allMatches(pathData)) {
    final String gap = pathData.substring(consumedUntil, match.start);
    if (!_separatorPattern.hasMatch(gap)) {
      throw FormatException('Unexpected path text', pathData, consumedUntil);
    }
    tokens.add(match.group(0)!);
    consumedUntil = match.end;
  }

  final String tail = pathData.substring(consumedUntil);
  if (!_separatorPattern.hasMatch(tail)) {
    throw FormatException('Unexpected path text', pathData, consumedUntil);
  }

  return tokens;
}

Path parseIconPath(String pathData) {
  final _IconPathBuilder builder = _IconPathBuilder(
    tokenizeIconPath(pathData),
  );

  return builder.build();
}

final class _IconPathBuilder {
  _IconPathBuilder(this._tokens);

  final List<String> _tokens;
  final Path _path = Path();
  int _position = 0;
  Offset _current = Offset.zero;
  Offset _subpathStart = Offset.zero;

  Path build() {
    String? command;

    while (_position < _tokens.length) {
      final String token = _tokens[_position];
      if (_commandPattern.hasMatch(token)) {
        command = token;
        _position += 1;
      } else if (command == null) {
        throw const FormatException('Path must start with a command');
      }

      command = _applyCommand(command);
    }

    return _path;
  }

  String _applyCommand(String command) {
    final bool isRelative = command == command.toLowerCase();
    final Offset origin = isRelative ? _current : Offset.zero;

    switch (command.toUpperCase()) {
      case 'M':
        _current = origin + _readPoint();
        _subpathStart = _current;
        _path.moveTo(_current.dx, _current.dy);
        return isRelative ? 'l' : 'L';
      case 'L':
        _current = origin + _readPoint();
        _path.lineTo(_current.dx, _current.dy);
        return command;
      case 'H':
        final double horizontal = _readNumber();
        _current = Offset(horizontal + origin.dx, _current.dy);
        _path.lineTo(_current.dx, _current.dy);
        return command;
      case 'V':
        final double vertical = _readNumber();
        _current = Offset(_current.dx, vertical + origin.dy);
        _path.lineTo(_current.dx, _current.dy);
        return command;
      case 'C':
        _applyCurve(origin);
        return command;
      case 'A':
        _applyArc(origin);
        return command;
      default:
        _path.close();
        _current = _subpathStart;
        return command;
    }
  }

  void _applyCurve(Offset origin) {
    _requireNumbers(_curveNumberCount);
    final Offset firstControl = origin + _readPoint();
    final Offset secondControl = origin + _readPoint();
    final Offset end = origin + _readPoint();

    _path.cubicTo(
      firstControl.dx,
      firstControl.dy,
      secondControl.dx,
      secondControl.dy,
      end.dx,
      end.dy,
    );
    _current = end;
  }

  void _applyArc(Offset origin) {
    _requireNumbers(_arcNumberCount);
    final double horizontalRadius = _readNumber();
    final double verticalRadius = _readNumber();
    final double rotation = _readNumber();
    final double largeArcFlag = _readNumber();
    final double sweepFlag = _readNumber();
    final Offset end = origin + _readPoint();

    _path.arcToPoint(
      end,
      radius: Radius.elliptical(horizontalRadius, verticalRadius),
      rotation: rotation,
      largeArc: largeArcFlag != 0,
      clockwise: sweepFlag != 0,
    );
    _current = end;
  }

  Offset _readPoint() {
    _requireNumbers(_coordinateCount);
    final double horizontal = _readNumber();
    final double vertical = _readNumber();

    return Offset(horizontal, vertical);
  }

  void _requireNumbers(int count) {
    final int end = _position + count;
    if (end > _tokens.length) {
      throw const FormatException('Path command is missing numbers');
    }
    for (int index = _position; index < end; index += 1) {
      if (_commandPattern.hasMatch(_tokens[index])) {
        throw const FormatException('Path command is missing numbers');
      }
    }
  }

  double _readNumber() {
    _requireNumbers(1);
    final double number = double.parse(_tokens[_position]);
    _position += 1;

    return number;
  }
}
