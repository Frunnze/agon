import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String _allWorkspacesLabel = 'All workspaces';
const String _noWorkspaceLabel = 'No workspace';
const String _listSeparator = ', ';
const String _partSeparator = ' · ';
const String _notSetUpLabel = 'Not set up';

String describeAvailability(
  WorkspaceScope availability,
  List<Workspace> workspaces,
) {
  switch (availability) {
    case AllWorkspaces():
      return _allWorkspacesLabel;
    case OnlyWorkspaces():
      final List<String> names = <String>[];
      for (final WorkspaceId workspaceId in availability.workspaces) {
        for (final Workspace workspace in workspaces) {
          if (workspace.id == workspaceId) {
            names.add(workspace.name);
          }
        }
      }
      if (names.isEmpty) {
        return _noWorkspaceLabel;
      }
      return names.join(_listSeparator);
  }
}

SignatureState findSignatureState(Workflow workflow, WorkflowChange? change) {
  if (workflow.signature == null) {
    return SignatureState.notSignedYet;
  }
  if (change != null) {
    return SignatureState.changedNotSigned;
  }
  return SignatureState.signed;
}

String describeSignatureState(SignatureState state) {
  switch (state) {
    case SignatureState.signed:
      return 'Signed';
    case SignatureState.notSignedYet:
      return 'Not signed yet';
    case SignatureState.changedNotSigned:
      return 'Changed, not signed';
  }
}

StatusLabel buildSignatureLabel(SignatureState state) {
  final bool isSigned = state == SignatureState.signed;

  return StatusLabel(
    text: describeSignatureState(state),
    tone: isSigned ? StatusTone.muted : StatusTone.attention,
    icon: isSigned ? AppIconKind.check : AppIconKind.alert,
  );
}

String describeAgentKind(AgentKind? kind) {
  return kind?.label ?? _notSetUpLabel;
}

String describeAgentTarget(RunnerTarget target, DeviceNames deviceNames) {
  switch (target) {
    case AnyFreeRunner():
      return 'any free runner';
    case SpecificRunner():
      return deviceNames.nameOf(target.deviceId);
    case RunnerWithLabels():
      return 'any ${target.labels.join(' ')} runner';
  }
}

String describeAgentNames(Workflow workflow) {
  if (workflow.agents.isEmpty) {
    return 'No agents yet';
  }

  final List<String> names = <String>[
    for (final WorkflowAgent agent in orderAgents(workflow)) agent.name,
  ];
  return names.join(_listSeparator);
}

String describeLastUse(DateTime? lastUsedAt, DateTime now) {
  if (lastUsedAt == null) {
    return 'Never';
  }
  return describeTimeSince(lastUsedAt, now);
}

String describeBuilderSummary({
  required Workflow workflow,
  required SignatureState state,
  required List<Workspace> workspaces,
}) {
  final String agents = describeCount(
    workflow.agents.length,
    singular: 'agent',
    plural: 'agents',
  );
  final String availability = describeAvailability(
    workflow.availability,
    workspaces,
  );
  final String signature = describeSignatureState(state).toLowerCase();

  return <String>[
    agents,
    lowercaseFirstLetter(availability),
    signature,
  ].join(_partSeparator);
}

String describeSignedSummary({
  required Workflow workflow,
  required List<Workspace> workspaces,
  required DeviceNames deviceNames,
  required DateTime now,
}) {
  final String availability = lowercaseFirstLetter(
    describeAvailability(workflow.availability, workspaces),
  );
  final WorkflowSignature? signature = workflow.signature;
  if (signature == null) {
    return 'In $availability · not signed yet';
  }

  final String signer = deviceNames.nameOf(signature.signedBy);
  final DateTime? signedAt = signature.signedAt;
  if (signedAt == null) {
    return 'In $availability · signed on $signer';
  }

  final String since = lowercaseFirstLetter(describeTimeSince(signedAt, now));
  return 'In $availability · signed on $signer $since';
}

int _countOnline(List<Runner> runners, bool Function(Runner) isMatch) {
  int count = 0;
  for (final Runner runner in runners) {
    if (runner.online && isMatch(runner)) {
      count += 1;
    }
  }
  return count;
}

StatusLabel _buildOnlineLabel(String text) {
  return StatusLabel(
    text: text,
    tone: StatusTone.normal,
    icon: AppIconKind.online,
  );
}

StatusLabel _buildOfflineLabel(String text) {
  return StatusLabel(
    text: text,
    tone: StatusTone.attention,
    icon: AppIconKind.offline,
  );
}

StatusLabel buildRunnerMatchLabel(RunnerTarget target, List<Runner> runners) {
  switch (target) {
    case SpecificRunner():
      final int online = _countOnline(
        runners,
        (Runner runner) => runner.deviceId == target.deviceId,
      );
      return online > 0
          ? _buildOnlineLabel('Online')
          : _buildOfflineLabel('Offline');
    case RunnerWithLabels():
      final int matches = _countOnline(
        runners,
        (Runner runner) => target.labels.every(runner.labels.contains),
      );
      if (matches == 0) {
        return _buildOfflineLabel('No match online');
      }
      final String noun = matches == 1 ? 'match' : 'matches';
      return _buildOnlineLabel('$matches $noun online');
    case AnyFreeRunner():
      final int online = _countOnline(runners, (Runner _) => true);
      if (online == 0) {
        return _buildOfflineLabel('No runner online');
      }
      return _buildOnlineLabel(
        '${describeCount(online, singular: 'runner', plural: 'runners')} '
        'online',
      );
  }
}

DateTime? findLastWorkflowUse({
  required WorkflowId workflowId,
  required List<Task> tasks,
  required List<Run> Function(TaskId taskId) listRuns,
}) {
  final TaskDoer doer = WorkflowDoer(workflowId);
  DateTime? latest;

  for (final Task task in tasks) {
    if (task.doer != doer) {
      continue;
    }
    for (final Run run in listRuns(task.id)) {
      if (latest == null || run.startedAt.isAfter(latest)) {
        latest = run.startedAt;
      }
    }
  }
  return latest;
}

List<TextSegment> describeStepRunsOn(
  RunnerTarget target,
  DeviceNames deviceNames,
) {
  final List<TextSegment> segments = describeRunnerTarget(target, deviceNames);

  if (target is SpecificRunner) {
    return <TextSegment>[const TextSegment('Runs on '), ...segments];
  }
  return segments;
}

String describeChangeSummary({
  required WorkflowChange change,
  required DeviceNames deviceNames,
  required DateTime now,
}) {
  final List<String> parts = <String>['Changed'];

  final DateTime? changedAt = change.changedAt;
  if (changedAt != null) {
    parts.add(lowercaseFirstLetter(describeTimeSince(changedAt, now)));
  }

  final DeviceId? changedBy = change.changedBy;
  if (changedBy != null) {
    parts.add('on ${deviceNames.nameOf(changedBy)}');
  }
  return parts.join(' ');
}

String describeKeptVersion(WorkflowSignature? signature, DateTime now) {
  if (signature == null) {
    return 'Until then, runners cannot run it.';
  }

  final DateTime? signedAt = signature.signedAt;
  if (signedAt == null) {
    return 'Until then, runners keep using the signed version.';
  }

  final String since = lowercaseFirstLetter(describeTimeSince(signedAt, now));
  return 'Until then, runners keep using the version signed $since.';
}
