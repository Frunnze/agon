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
