const String _pathSeparator = '/';
const String _rootFolder = '';

String fileNameOf(String path) {
  final int separatorIndex = path.lastIndexOf(_pathSeparator);

  return path.substring(separatorIndex + 1);
}

String parentFolderOf(String path) {
  final int separatorIndex = path.lastIndexOf(_pathSeparator);
  if (separatorIndex < 0) {
    return _rootFolder;
  }
  return path.substring(0, separatorIndex);
}

String joinRepositoryPath(String folder, String name) {
  if (folder.isEmpty) {
    return name;
  }
  return '$folder$_pathSeparator$name';
}

List<String> listAncestorFolders(String path) {
  final List<String> segments = path.split(_pathSeparator);
  final List<String> ancestors = <String>[_rootFolder];

  for (int index = 1; index < segments.length; index += 1) {
    ancestors.add(segments.sublist(0, index).join(_pathSeparator));
  }

  return ancestors;
}

List<String> describeBreadcrumb(String repositoryPath, String filePath) {
  final List<String> segments = filePath.split(_pathSeparator);
  final List<String> folderNames = segments.sublist(0, segments.length - 1);

  return <String>[repositoryPath, ...folderNames];
}
