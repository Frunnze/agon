const String _branchPrefix = 'task/';
const String _fallbackSlug = 'task';
final RegExp _unsafeRunPattern = RegExp('[^a-z0-9]+');
final RegExp _edgeDashPattern = RegExp(r'^-+|-+$');

String slugifyTaskTitle(String title) {
  final String lowered = title.toLowerCase();
  final String dashed = lowered.replaceAll(_unsafeRunPattern, '-');
  final String trimmed = dashed.replaceAll(_edgeDashPattern, '');

  if (trimmed.isEmpty) {
    return _fallbackSlug;
  }
  return trimmed;
}

String describeTaskBranch(String title) {
  return '$_branchPrefix${slugifyTaskTitle(title)}';
}

String describeJobRunBranch(String title, int runNumber) {
  return '${describeTaskBranch(title)}-run-$runNumber';
}
