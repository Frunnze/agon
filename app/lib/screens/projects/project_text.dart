import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String _pathSeparator = '/';
const String _listSeparator = ', ';
const String _partSeparator = ' · ';
const String _everywhereLabel = 'Everywhere';
const String _thisProjectLabel = 'This project';
const String repositoryAlreadyAddedProblem = 'This repo is already added';

String describeRepositoryPlace(String address, DeviceNames deviceNames) {
  final LocalFolderAddress? folder = parseLocalFolderAddress(address);
  if (folder != null) {
    return 'on ${deviceNames.describeDevice(folder.deviceId)}';
  }
  return address.split(_pathSeparator).first;
}

String describeRepositoryPaths(Project project) {
  final List<String> paths = <String>[
    for (final Repository repository in project.repositories)
      describeRepositoryPath(repository.address),
  ];

  return paths.join(_listSeparator);
}

String describeRunAge(DateTime moment, DateTime now) {
  final int days = countCalendarDaysBetween(moment, now);

  if (days <= 0) {
    return 'Ran today';
  }
  if (days == 1) {
    return 'Ran yesterday';
  }
  return 'Ran $days days ago';
}

StatusLabel buildProjectActivityLabel({
  required int runningTaskCount,
  required DateTime? lastRunAt,
  required DateTime now,
}) {
  if (runningTaskCount > 0) {
    final String tasks = describeCount(
      runningTaskCount,
      singular: 'task',
      plural: 'tasks',
    );
    return StatusLabel(
      text: '$tasks running',
      tone: StatusTone.normal,
      icon: AppIconKind.spinner,
    );
  }
  if (lastRunAt == null) {
    return const StatusLabel(
      text: 'No runs yet',
      tone: StatusTone.muted,
      icon: AppIconKind.clock,
    );
  }
  return StatusLabel(
    text: describeRunAge(lastRunAt, now),
    tone: StatusTone.muted,
    icon: AppIconKind.clock,
  );
}

String describeAgentAccess(AgentAccess access) {
  switch (access) {
    case AgentAccess.readOnly:
      return 'Read only';
    case AgentAccess.pushAfterApproval:
      return 'Read and push';
  }
}

StatusLabel buildAgentAccessLabel(AgentAccess access) {
  switch (access) {
    case AgentAccess.readOnly:
      return StatusLabel(
        text: describeAgentAccess(access),
        tone: StatusTone.muted,
        icon: AppIconKind.lock,
      );
    case AgentAccess.pushAfterApproval:
      return StatusLabel(
        text: describeAgentAccess(access),
        tone: StatusTone.normal,
        icon: AppIconKind.approval,
      );
  }
}

String describeWorkspaceContents({
  required int projectCount,
  required int runnerCount,
}) {
  final String projects = describeCount(
    projectCount,
    singular: 'project',
    plural: 'projects',
  );
  final String runners = describeCount(
    runnerCount,
    singular: 'runner',
    plural: 'runners',
  );

  return '$projects$_partSeparator$runners';
}

int countWorkspaceRunners({
  required WorkspaceId workspaceId,
  required List<Runner> runners,
  required List<Device> devices,
}) {
  int count = 0;

  for (final Runner runner in runners) {
    for (final Device device in devices) {
      final bool isRunnerDevice = device.id == runner.deviceId;
      if (isRunnerDevice && device.workspaces.contains(workspaceId)) {
        count += 1;
      }
    }
  }
  return count;
}

String describeRuleReach({
  required Scope scope,
  required Project project,
  required ScopeCatalog catalog,
}) {
  final WorkspaceScope workspaces = scope.workspaces;
  final ProjectScope projects = scope.projects;

  if (workspaces is AllWorkspaces && projects is AllProjects) {
    return _everywhereLabel;
  }
  if (projects is OnlyProjects &&
      projects.projects.length == 1 &&
      projects.projects.first == project.id) {
    return _thisProjectLabel;
  }
  if (workspaces is OnlyWorkspaces && projects is AllProjects) {
    final List<String> names = <String>[
      for (final WorkspaceId workspaceId in workspaces.workspaces)
        catalog.nameOfWorkspace(workspaceId),
    ];
    return 'All ${names.join(_listSeparator)} projects';
  }
  return describeScopeLine(scope, catalog);
}

String? describeRepositoryEntryProblem({
  required String text,
  required List<String> addedAddresses,
}) {
  final String? address = parseRepositoryAddress(text);

  if (address == null) {
    return 'Paste an address like github.com/acme/repo';
  }
  if (addedAddresses.contains(address)) {
    return repositoryAlreadyAddedProblem;
  }
  return null;
}
