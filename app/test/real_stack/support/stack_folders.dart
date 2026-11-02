import 'dart:io';

const List<String> _gitTestSettings = <String>[
  '-c',
  'user.name=Real Stack Test',
  '-c',
  'user.email=real-stack@example.com',
  '-c',
  'commit.gpgsign=false',
  '-c',
  'core.hooksPath=/dev/null',
];

Future<void> _runGit(Directory directory, List<String> arguments) async {
  final ProcessResult outcome = await Process.run('git', <String>[
    ..._gitTestSettings,
    ...arguments,
  ], workingDirectory: directory.path);
  if (outcome.exitCode != 0) {
    throw StateError('git ${arguments.first} failed: ${outcome.stderr}');
  }
}

Future<Directory> createGitFolder(Directory parent, String folderName) async {
  final Directory folder = Directory('${parent.path}/$folderName')
    ..createSync(recursive: true);
  File('${folder.path}/README.md').writeAsStringSync('hello');
  await _runGit(folder, <String>['init', '--quiet', '--initial-branch=main']);
  await _runGit(folder, <String>['add', '--all']);
  await _runGit(folder, <String>['commit', '--quiet', '-m', 'Start']);
  return folder;
}
