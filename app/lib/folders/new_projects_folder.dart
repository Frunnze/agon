import 'dart:io';

const String _newProjectsFolderName = 'Agon';
const List<String> _homeVariables = <String>['HOME', 'USERPROFILE'];

String describeNewProjectsFolder(Map<String, String> environment) {
  for (final String variable in _homeVariables) {
    final String home = _removeTrailingSeparators(environment[variable] ?? '');
    if (home.isNotEmpty) {
      return '$home${Platform.pathSeparator}$_newProjectsFolderName';
    }
  }
  throw StateError('Neither HOME nor USERPROFILE names a home folder');
}

Future<String> makeNewProjectsFolder(Map<String, String> environment) async {
  final Directory folder = Directory(describeNewProjectsFolder(environment));
  await folder.create(recursive: true);
  return folder.path;
}

String _removeTrailingSeparators(String path) {
  String trimmed = path.trim();
  while (trimmed.length > 1 && trimmed.endsWith(Platform.pathSeparator)) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
