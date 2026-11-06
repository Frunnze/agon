import 'dart:io';
import 'dart:math';

const String _configurationHomeVariable = 'XDG_CONFIG_HOME';
const String _blockingFileText = 'in the way';
const String _fileInsideBlockingFolder = 'keeps the folder full';
const int _largestFolderDepth = 3;
const int _folderNumberSpan = 100;

Map<String, String> randomEnvironmentInside(Random random, Directory root) {
  final StringBuffer configurationHome = StringBuffer(root.path);
  final int depth = random.nextInt(_largestFolderDepth);
  for (int i = 0; i < depth; i += 1) {
    configurationHome.write('/folder ${random.nextInt(_folderNumberSpan)}');
  }
  return <String, String>{_configurationHomeVariable: '$configurationHome'};
}

List<String> listFoldersBetween({
  required Directory root,
  required String entryPath,
}) {
  final List<String> folders = <String>[];
  String folder = File(entryPath).parent.path;
  while (folder.length > root.path.length) {
    folders.add(folder);
    folder = Directory(folder).parent.path;
  }
  return folders;
}

void blockWithFile(String path) {
  Directory(File(path).parent.path).createSync(recursive: true);
  File(path).writeAsStringSync(_blockingFileText);
}

void blockWithFolder(String entryPath) {
  File('$entryPath/$_fileInsideBlockingFolder').createSync(recursive: true);
}
