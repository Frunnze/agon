const String _backslash = r'\';
const String _doubleQuote = '"';
const String _percent = '%';
const String _space = ' ';
const Map<String, String> _stringEscapes = <String, String>{
  's': ' ',
  'n': '\n',
  't': '\t',
  'r': '\r',
  _backslash: _backslash,
};
const Set<String> _quotedEscapes = <String>{
  _doubleQuote,
  '`',
  r'$',
  _backslash,
};

String readDesktopEntryValue(String entryText, String key) {
  final String prefix = '$key=';
  for (final String line in entryText.split('\n')) {
    if (line.startsWith(prefix)) {
      return line.substring(prefix.length);
    }
  }
  throw StateError('the desktop entry has no $key key');
}

String _unescapeStringValue(String value) {
  final StringBuffer text = StringBuffer();
  int i = 0;
  while (i < value.length) {
    final String character = value[i];
    if (character != _backslash) {
      text.write(character);
      i += 1;
      continue;
    }
    final String? meaning = _stringEscapes[value[i + 1]];
    if (meaning == null) {
      throw FormatException('unknown string escape in $value');
    }
    text.write(meaning);
    i += 2;
  }
  return text.toString();
}

String _expandPercentCodes(String commandLine) {
  final StringBuffer text = StringBuffer();
  int i = 0;
  while (i < commandLine.length) {
    final String character = commandLine[i];
    if (character != _percent) {
      text.write(character);
      i += 1;
      continue;
    }
    if (commandLine[i + 1] != _percent) {
      throw FormatException('unexpected field code in $commandLine');
    }
    text.write(_percent);
    i += 2;
  }
  return text.toString();
}

List<String> _splitQuotedArguments(String commandLine) {
  final List<String> arguments = <String>[];
  final StringBuffer argument = StringBuffer();
  bool hasArgument = false;
  bool isQuoted = false;
  int i = 0;
  while (i < commandLine.length) {
    final String character = commandLine[i];
    if (isQuoted && character == _backslash) {
      final String escaped = commandLine[i + 1];
      if (!_quotedEscapes.contains(escaped)) {
        throw FormatException('unknown quoted escape in $commandLine');
      }
      argument.write(escaped);
      i += 2;
      continue;
    }
    if (character == _doubleQuote) {
      isQuoted = !isQuoted;
      hasArgument = true;
    } else if (!isQuoted && character == _space) {
      if (hasArgument) {
        arguments.add(argument.toString());
      }
      argument.clear();
      hasArgument = false;
    } else {
      argument.write(character);
      hasArgument = true;
    }
    i += 1;
  }
  if (isQuoted) {
    throw FormatException('unclosed quote in $commandLine');
  }
  if (hasArgument) {
    arguments.add(argument.toString());
  }
  return arguments;
}

List<String> parseDesktopEntryExec(String execValue) {
  final String commandLine = _unescapeStringValue(execValue);
  final String expandedCommandLine = _expandPercentCodes(commandLine);
  return _splitQuotedArguments(expandedCommandLine);
}
