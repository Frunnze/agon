import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../bridge/support/local_orchestration_server.dart';
import 'runner_node_process.dart';

const String localRepositoryAddress = 'local.test/acme/app';
const String releaseFileName = 'release';
const String resumedFileName = 'resumed.txt';
const String _fakeAgentFolder = 'test/real_stack/fake_agent';
const String _searchPathVariable = 'PATH';
const String _recordsVariable = 'AGENT_RECORDS';
const String _runnerLabel = 'mac';
const String _runnerRole = 'runner';
const String _approvedState = 'approved';
const String _taskBranchPattern = 'task/*';
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

final class RunnerDevice {
  RunnerDevice._({
    required this.deviceName,
    required this.node,
    required this.recordsDirectory,
    required this.originDirectory,
  });

  final String deviceName;
  final RunnerNodeProcess node;
  final Directory recordsDirectory;
  final Directory originDirectory;

  static Future<RunnerDevice> start({
    required Directory workingDirectory,
    required String deviceName,
  }) async {
    final Directory records = Directory('${workingDirectory.path}/records')
      ..createSync();
    final Directory originRoot = Directory('${workingDirectory.path}/origin')
      ..createSync();
    final Directory origin = await _createLocalOrigin(originRoot);
    final String inheritedPath =
        Platform.environment[_searchPathVariable] ?? '';
    final String fakeAgentPath = '${Directory.current.path}/$_fakeAgentFolder';
    final int appServerPort = await findFreePort();

    final RunnerNodeProcess node = await RunnerNodeProcess.start(
      configuration: <String, Object?>{
        'data_directory': '${workingDirectory.path}/runner',
        'identity_store': 'file',
        'peer_relay': 'disabled',
        'app_server_port': appServerPort,
        'runner': <String, Object?>{
          'labels': <String>[_runnerLabel],
          'slot_capacity': 1,
          'sandbox': <String, Object?>{'kind': 'local_process'},
          'clone_url_template': 'file://${originRoot.path}/{address}',
        },
      },
      environment: <String, String>{
        _searchPathVariable: '$fakeAgentPath:$inheritedPath',
        _recordsVariable: records.path,
      },
    );
    addTearDown(node.stop);
    return RunnerDevice._(
      deviceName: deviceName,
      node: node,
      recordsDirectory: records,
      originDirectory: origin,
    );
  }

  Future<void> joinWithCode({
    required String serverAddress,
    required String code,
  }) async {
    await node.run(<String, Object?>{
      'command': 'join_with_code',
      'server_address': serverAddress,
      'code': code,
      'device_name': deviceName,
      'role': _runnerRole,
    });
  }

  Future<List<String>> readJoinWords() async {
    final Object? status = await node.run(<String, Object?>{
      'command': 'join_status',
    });
    return readListField(
      decodeObject(status),
      'fingerprint_words',
      decodeText,
    );
  }

  Future<String?> readJoinProblem({
    required String serverAddress,
    required String code,
  }) {
    return node.readProblem(<String, Object?>{
      'command': 'join_with_code',
      'server_address': serverAddress,
      'code': code,
      'device_name': deviceName,
      'role': _runnerRole,
    });
  }

  Future<String> readJoinState() async {
    final Object? status = await node.run(<String, Object?>{
      'command': 'join_status',
    });
    return readField(decodeObject(status), 'state', decodeText);
  }

  Future<bool> isApproved() async {
    return await readJoinState() == _approvedState;
  }

  Future<String?> readDeviceListRefusal() {
    return node.readProblem(<String, Object?>{'command': 'list_devices'});
  }

  void releaseAgent() {
    File('${recordsDirectory.path}/$releaseFileName').writeAsStringSync('');
  }

  bool hasRecord(String fileName) {
    return File('${recordsDirectory.path}/$fileName').existsSync();
  }

  String readRecord(String fileName) {
    return File('${recordsDirectory.path}/$fileName').readAsStringSync();
  }

  Future<List<String>> listPushedTaskBranches() async {
    final String branches = await _runGit(originDirectory, <String>[
      'branch',
      '--list',
      _taskBranchPattern,
    ]);
    return <String>[
      for (final String line in branches.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }
}

Future<Directory> _createLocalOrigin(Directory originRoot) async {
  final Directory seed = Directory('${originRoot.path}/seed')..createSync();
  await _runGit(seed, <String>['init', '--quiet', '--initial-branch=main']);
  File('${seed.path}/README.md').writeAsStringSync('hello\n');
  await _runGit(seed, <String>['add', '--all']);
  await _runGit(seed, <String>['commit', '--quiet', '--message', 'Start']);

  final Directory origin = Directory(
    '${originRoot.path}/$localRepositoryAddress',
  );
  origin.parent.createSync(recursive: true);
  await _runGit(originRoot, <String>[
    'clone',
    '--quiet',
    '--bare',
    seed.path,
    origin.path,
  ]);
  return origin;
}

Future<String> _runGit(Directory directory, List<String> arguments) async {
  final ProcessResult outcome = await Process.run('git', <String>[
    ..._gitTestSettings,
    ...arguments,
  ], workingDirectory: directory.path);
  if (outcome.exitCode != 0) {
    throw StateError('git ${arguments.first} failed: ${outcome.stderr}');
  }
  return '${outcome.stdout}';
}
