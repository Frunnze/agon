import 'package:agent_orchestration/product_name.dart';

const String _applicationId = 'dev.orchestration.agent_orchestration';
const String _configurationHomeVariable = 'XDG_CONFIG_HOME';
const String _homeVariable = 'HOME';
const String _defaultConfigurationFolder = '.config';
const String _autostartFolder = 'autostart';
const String _entryExtension = '.desktop';
const String _rootFolder = '/';
const String _doubleQuote = '"';
const String _backslash = r'\';
const String _percent = '%';
const Set<String> _charactersEscapedInQuotes = <String>{
  _doubleQuote,
  '`',
  r'$',
  _backslash,
};
const int _firstPrintableCodeUnit = 0x20;
const int _deleteCodeUnit = 0x7f;
const String _missingFolderProblem =
    'could not find the autostart folder: neither XDG_CONFIG_HOME nor HOME '
    'names an absolute folder';

bool _isAbsolute(String path) {
  return path.startsWith(_rootFolder);
}

String _findConfigurationHome(Map<String, String> environment) {
  final String? configurationHome = environment[_configurationHomeVariable];
  if (configurationHome != null && _isAbsolute(configurationHome)) {
    return configurationHome;
  }

  final String? home = environment[_homeVariable];
  if (home == null || !_isAbsolute(home)) {
    throw StateError(_missingFolderProblem);
  }
  return '$home/$_defaultConfigurationFolder';
}

String locateAutostartEntry(Map<String, String> environment) {
  final String configurationHome = _findConfigurationHome(environment);
  const String entryFileName = '$_applicationId$_entryExtension';
  return '$configurationHome/$_autostartFolder/$entryFileName';
}

bool _hasControlCharacter(String text) {
  for (final int codeUnit in text.codeUnits) {
    if (codeUnit < _firstPrintableCodeUnit || codeUnit == _deleteCodeUnit) {
      return true;
    }
  }
  return false;
}

void _checkExecutablePath(String executablePath) {
  if (!_isAbsolute(executablePath)) {
    throw ArgumentError.value(
      executablePath,
      'executablePath',
      'the app can start at login only from an absolute path',
    );
  }
  if (_hasControlCharacter(executablePath)) {
    throw ArgumentError.value(
      executablePath,
      'executablePath',
      'the app path holds a control character',
    );
  }
}

String _quoteArgument(String argument) {
  final StringBuffer quoted = StringBuffer(_doubleQuote);
  for (final String character in argument.split('')) {
    if (_charactersEscapedInQuotes.contains(character)) {
      quoted.write(_backslash);
    }
    quoted.write(character);
  }
  quoted.write(_doubleQuote);
  return quoted.toString();
}

String renderAutostartEntry(String executablePath) {
  _checkExecutablePath(executablePath);

  final String quotedPath = _quoteArgument(executablePath);
  final String percentEscapedPath = quotedPath.replaceAll(
    _percent,
    '$_percent$_percent',
  );
  final String execValue = percentEscapedPath.replaceAll(
    _backslash,
    '$_backslash$_backslash',
  );

  return '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=$productName\n'
      'Exec=$execValue\n';
}
