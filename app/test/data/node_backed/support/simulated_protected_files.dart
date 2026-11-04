import 'simulated_node_replies.dart';

const List<String> simulatedDefaultProtectedFiles = <String>[
  '.env',
  '~/.ssh',
  '*.pem',
];

Map<String, Object?> buildSimulatedProtectedFilesJson(List<Object?> patterns) {
  return <String, Object?>{
    'patterns': <Object?>[...patterns],
  };
}

final class SimulatedProtectedFiles {
  SimulatedProtectedFiles({required this.workspaces});

  final List<Map<String, Object?>> workspaces;

  Object? setProtectedFiles(SimulatedCommand command) {
    final Map<String, Object?> workspace = _findWorkspace(command);
    final List<Object?> patterns = command['patterns']! as List<Object?>;

    workspace['protected_files'] = buildSimulatedProtectedFilesJson(patterns);
    return workspace;
  }

  Object? resetProtectedFiles(SimulatedCommand command) {
    final Map<String, Object?> workspace = _findWorkspace(command);

    workspace['protected_files'] = buildSimulatedProtectedFilesJson(
      simulatedDefaultProtectedFiles,
    );
    return workspace;
  }

  Map<String, Object?> _findWorkspace(SimulatedCommand command) {
    return findSimulatedRecord(
      workspaces,
      kind: 'workspace',
      identifier: command['workspace_id'],
    );
  }
}
