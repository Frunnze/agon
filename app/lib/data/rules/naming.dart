const int nameMaximumLength = 40;
final RegExp _allowedNamePattern = RegExp(r'^[a-z0-9-]+$');

String? describeNameProblem(String name) {
  if (name.isEmpty) {
    return 'Give it a name';
  }
  if (name.length > nameMaximumLength) {
    return 'Use at most $nameMaximumLength characters';
  }
  if (!_allowedNamePattern.hasMatch(name)) {
    return 'Use lowercase letters, digits and dashes';
  }
  return null;
}

const String fallbackProjectName = 'project';
const String _nameSeparator = '-';
final RegExp _projectNameCharacterPattern = RegExp(r'^[a-z0-9]$');

String convertToProjectName(String folderOrRepositoryName) {
  final String lowercaseName = folderOrRepositoryName.toLowerCase();
  String projectName = '';
  for (final String character in lowercaseName.split('')) {
    final bool isAfterWord =
        projectName.isNotEmpty && !projectName.endsWith(_nameSeparator);
    if (_projectNameCharacterPattern.hasMatch(character)) {
      projectName = '$projectName$character';
    } else if (isAfterWord) {
      projectName = '$projectName$_nameSeparator';
    }
  }

  String shortened = projectName;
  if (shortened.length > nameMaximumLength) {
    shortened = shortened.substring(0, nameMaximumLength);
  }
  if (shortened.endsWith(_nameSeparator)) {
    shortened = shortened.substring(0, shortened.length - 1);
  }
  if (shortened.isEmpty) {
    return fallbackProjectName;
  }
  return shortened;
}
