import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

import 'simulated_deletions.dart';
import 'simulated_library_edits.dart';
import 'simulated_node_replies.dart';
import 'simulated_project_edits.dart';
import 'simulated_protected_files.dart';
import 'simulated_scopes.dart';
import 'simulated_server_group.dart';
import 'simulated_work_node.dart' show SimulatedWorkNode;

const String simulatedServerAddress = 'http://127.0.0.1:7070';
const String simulatedDeviceId = 'simulated-this-device';

final class SimulatedCatalogNode {
  SimulatedCatalogNode({required this.hasAccount});

  bool hasAccount;
  bool isServerReachable = true;
  final List<Map<String, Object?>> workspaces = <Map<String, Object?>>[];
  final List<Map<String, Object?>> projects = <Map<String, Object?>>[];
  final List<Map<String, Object?>> skills = <Map<String, Object?>>[];
  final List<Map<String, Object?>> rules = <Map<String, Object?>>[];
  final Set<String> failingCommands = <String>{};
  final SimulatedServerGroup serverGroup = SimulatedServerGroup(
    thisDeviceId: simulatedDeviceId,
  );
  final SimulatedWorkNode work = SimulatedWorkNode(
    thisDeviceId: simulatedDeviceId,
  );
  int _createdCount = 0;

  late final NodeCommandChannel channel = buildSimulatedChannel(answer);
  late final SimulatedCatalogDeletions _deletions = SimulatedCatalogDeletions(
    workspaces: workspaces,
    projects: projects,
    skills: skills,
    rules: rules,
    tasks: work.tasks,
    runs: work.runs,
  );
  late final SimulatedProjectEdits _projectEdits = SimulatedProjectEdits(
    projects: projects,
    nextIdentifier: nextIdentifier,
  );
  late final SimulatedLibraryEdits _libraryEdits = SimulatedLibraryEdits(
    skills: skills,
    rules: rules,
    tasks: work.tasks,
  );
  late final SimulatedProtectedFiles _protectedFiles = SimulatedProtectedFiles(
    workspaces: workspaces,
  );

  late final Map<String, SimulatedHandler> _handlers =
      <String, SimulatedHandler>{
        'status': _describeStatus,
        'retry_server': _checkServer,
        'list_workspaces': _listWorkspaces,
        'create_workspace': _createWorkspace,
        'change_workspace_approval_policy': _changeApprovalPolicy,
        'list_projects': _listProjects,
        'create_project': _projectEdits.createProject,
        'create_repository': _projectEdits.createRepository,
        'remove_repository': _projectEdits.removeRepository,
        'delete_project': _deletions.deleteProject,
        'delete_workspace': _deletions.deleteWorkspace,
        'list_skills': _listUsableSkills,
        'create_skill': _createSkill,
        'update_skill': _libraryEdits.updateSkill,
        'delete_skill': _libraryEdits.deleteSkill,
        'undo_skill_change': _libraryEdits.undoSkillChange,
        'list_rules': _listUsableRules,
        'create_rule': _createRule,
        'update_rule': _libraryEdits.updateRule,
        'delete_rule': _libraryEdits.deleteRule,
        'set_rule_enabled': _setRuleEnabled,
        'start_server_backup': serverGroup.startBackup,
        'stop_server_backup': serverGroup.stopBackup,
        'set_protected_files': _protectedFiles.setProtectedFiles,
        'reset_protected_files': _protectedFiles.resetProtectedFiles,
      };

  String answer(String inputJson) {
    return answerSimulatedCommand(
      inputJson: inputJson,
      handlers: _handlers,
      failingCommands: failingCommands,
    );
  }

  String nextIdentifier(String kind) {
    _createdCount += 1;
    return '$kind-$_createdCount';
  }

  Map<String, Object?> addWorkspace(String name) {
    final Map<String, Object?> workspace = <String, Object?>{
      'id': nextIdentifier('workspace'),
      'name': name,
      'app_server_address': simulatedServerAddress,
      'protected_files': buildSimulatedProtectedFilesJson(
        simulatedDefaultProtectedFiles,
      ),
    };
    workspaces.add(workspace);
    return workspace;
  }

  Map<String, Object?> addSkill({
    required String workspaceId,
    required String name,
  }) {
    final Map<String, Object?> skill = <String, Object?>{
      'id': nextIdentifier('skill'),
      'name': name,
      'summary': 'Summary of $name',
      'instructions': 'Instructions of $name',
      'scope': buildSimulatedScopeOnlyIn(workspaceId),
      'usage': 'when_chosen',
      'source': 'created',
      'improvement': 'never',
      'history': <Object?>[],
    };
    skills.add(skill);
    return skill;
  }

  Map<String, Object?> addRule({
    required String workspaceId,
    required String title,
  }) {
    final Map<String, Object?> rule = <String, Object?>{
      'id': nextIdentifier('rule'),
      'title': title,
      'details': 'Details of $title',
      'scope': buildSimulatedScopeOnlyIn(workspaceId),
      'enabled': true,
      'added_at': simulatedMoment,
    };
    rules.add(rule);
    return rule;
  }

  Object? _describeStatus(SimulatedCommand command) {
    final Map<String, Object?> device = buildSimulatedDeviceJson(
      deviceId: simulatedDeviceId,
      name: 'laptop',
      sealingPublicKey: const <int>[3],
      approvedBy: null,
    );
    final Map<String, Object?>? account = hasAccount
        ? <String, Object?>{'device': device, 'workspaces': workspaces}
        : null;
    return <String, Object?>{
      'server_address': hasAccount ? simulatedServerAddress : null,
      'server_reachable': isServerReachable,
      'device_id': simulatedDeviceId,
      'account': account,
      'pending_join': null,
      'app_servers': serverGroup.describe(),
    };
  }

  Object? _checkServer(SimulatedCommand command) {
    return <String, Object?>{
      'reachable': isServerReachable,
      'checked_at': simulatedMoment,
      'problem': isServerReachable ? null : 'refused',
    };
  }

  Object? _listWorkspaces(SimulatedCommand command) {
    _requireAccount();
    return <Object?>[
      for (final Map<String, Object?> workspace in workspaces)
        <String, Object?>{
          'workspace': workspace,
          'project_count': 0,
          'runner_count': 0,
        },
    ];
  }

  Object? _createWorkspace(SimulatedCommand command) {
    _requireAccount();
    return addWorkspace(command['name'] as String);
  }

  Object? _changeApprovalPolicy(SimulatedCommand command) {
    final Map<String, Object?> workspace = findSimulatedRecord(
      workspaces,
      kind: 'workspace',
      identifier: command['workspace_id'],
    );
    workspace['approval_policy'] = command['approval_policy'];
    return workspace;
  }

  Object? _listProjects(SimulatedCommand command) {
    return <Object?>[
      for (final Map<String, Object?> project in projects)
        if (project['workspace_id'] == command['workspace_id'])
          <String, Object?>{
            'project': project,
            'task_count': 0,
            'running_task_count': 0,
          },
    ];
  }

  Object? _listUsableSkills(SimulatedCommand command) {
    return <Object?>[
      for (final Map<String, Object?> skill in skills)
        if (isSimulatedScopeInWorkspace(skill, command['workspace_id'])) skill,
    ];
  }

  Object? _listUsableRules(SimulatedCommand command) {
    return <Object?>[
      for (final Map<String, Object?> rule in rules)
        if (isSimulatedScopeInWorkspace(rule, command['workspace_id'])) rule,
    ];
  }

  Object? _createSkill(SimulatedCommand command) {
    final Map<String, Object?> skill = addSkill(
      workspaceId: command['workspace_id'] as String,
      name: command['name'] as String,
    );
    skill['summary'] = command['summary'];
    skill['instructions'] = command['instructions'];
    skill['scope'] = command['scope'];
    skill['usage'] = command['usage'];
    skill['improvement'] = command['improvement'];
    return skill;
  }

  Object? _createRule(SimulatedCommand command) {
    final Map<String, Object?> rule = addRule(
      workspaceId: command['workspace_id'] as String,
      title: command['title'] as String,
    );
    rule['details'] = command['details'];
    rule['scope'] = command['scope'];
    return rule;
  }

  Object? _setRuleEnabled(SimulatedCommand command) {
    final Map<String, Object?> rule = findSimulatedRecord(
      rules,
      kind: 'rule',
      identifier: command['rule_id'],
    );
    rule['enabled'] = command['enabled'];
    return null;
  }

  void _requireAccount() {
    if (!hasAccount) {
      throw const SimulatedNodeFailure.ofKind(
        'this device has no account yet',
        kind: noAccountFailureKind,
      );
    }
  }
}
