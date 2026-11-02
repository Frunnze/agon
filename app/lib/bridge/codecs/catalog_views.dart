import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

const String _peerAddressVerifiedField = 'peer_address_verified';

final class DeviceView implements JsonEncodable {
  DeviceView({
    required this.device,
    required this.isThisDevice,
    required List<String> workspaceNames,
    required this.peerAddressVerified,
  }) : workspaceNames = List<String>.unmodifiable(workspaceNames);

  factory DeviceView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return DeviceView(
      device: readField(fields, 'device', Device.fromJson),
      isThisDevice: readField(fields, 'is_this_device', decodeFlag),
      workspaceNames: readListField(fields, 'workspace_names', decodeText),
      peerAddressVerified: readField(
        fields,
        _peerAddressVerifiedField,
        decodeFlag,
      ),
    );
  }

  final Device device;
  final bool isThisDevice;
  final List<String> workspaceNames;
  final bool peerAddressVerified;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'device': device.toJson(),
      'is_this_device': isThisDevice,
      'workspace_names': workspaceNames,
      _peerAddressVerifiedField: peerAddressVerified,
    };
  }
}

final class WorkspaceView implements JsonEncodable {
  const WorkspaceView({
    required this.workspace,
    required this.projectCount,
    required this.runnerCount,
  });

  factory WorkspaceView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return WorkspaceView(
      workspace: readField(fields, 'workspace', Workspace.fromJson),
      projectCount: readField(fields, 'project_count', decodeInteger),
      runnerCount: readField(fields, 'runner_count', decodeInteger),
    );
  }

  final Workspace workspace;
  final int projectCount;
  final int runnerCount;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'workspace': workspace.toJson(),
      'project_count': projectCount,
      'runner_count': runnerCount,
    };
  }
}

final class ProjectView implements JsonEncodable {
  const ProjectView({
    required this.project,
    required this.taskCount,
    required this.runningTaskCount,
  });

  factory ProjectView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ProjectView(
      project: readField(fields, 'project', Project.fromJson),
      taskCount: readField(fields, 'task_count', decodeInteger),
      runningTaskCount: readField(fields, 'running_task_count', decodeInteger),
    );
  }

  final Project project;
  final int taskCount;
  final int runningTaskCount;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'project': project.toJson(),
      'task_count': taskCount,
      'running_task_count': runningTaskCount,
    };
  }
}

final class RunnerSummary implements JsonEncodable {
  const RunnerSummary({
    required this.runnerCount,
    required this.onlineCount,
    required this.freeSlotCount,
  });

  factory RunnerSummary.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunnerSummary(
      runnerCount: readField(fields, 'runner_count', decodeInteger),
      onlineCount: readField(fields, 'online_count', decodeInteger),
      freeSlotCount: readField(fields, 'free_slot_count', decodeInteger),
    );
  }

  final int runnerCount;
  final int onlineCount;
  final int freeSlotCount;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'runner_count': runnerCount,
      'online_count': onlineCount,
      'free_slot_count': freeSlotCount,
    };
  }
}

final class RunnerView implements JsonEncodable {
  const RunnerView({
    required this.runner,
    required this.deviceName,
    required this.freeSlots,
    required this.peerAddressVerified,
  });

  factory RunnerView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunnerView(
      runner: readField(fields, 'runner', Runner.fromJson),
      deviceName: readField(fields, 'device_name', decodeText),
      freeSlots: readField(fields, 'free_slots', decodeInteger),
      peerAddressVerified: readField(
        fields,
        _peerAddressVerifiedField,
        decodeFlag,
      ),
    );
  }

  final Runner runner;
  final String deviceName;
  final int freeSlots;
  final bool peerAddressVerified;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'runner': runner.toJson(),
      'device_name': deviceName,
      'free_slots': freeSlots,
      _peerAddressVerifiedField: peerAddressVerified,
    };
  }
}

final class RunnersView implements JsonEncodable {
  RunnersView({
    required this.summary,
    required this.summaryText,
    required List<RunnerView> runners,
    required this.thisDeviceProblem,
    required this.thisDeviceSettings,
  }) : runners = List<RunnerView>.unmodifiable(runners);

  factory RunnersView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return RunnersView(
      summary: readField(fields, 'summary', RunnerSummary.fromJson),
      summaryText: readField(fields, 'summary_text', decodeText),
      runners: readListField(fields, 'runners', RunnerView.fromJson),
      thisDeviceProblem: readOptionalField(
        fields,
        'this_device_problem',
        decodeText,
      ),
      thisDeviceSettings: readOptionalField(
        fields,
        'this_device_settings',
        RunnerSettings.fromJson,
      ),
    );
  }

  final RunnerSummary summary;
  final String summaryText;
  final List<RunnerView> runners;
  final String? thisDeviceProblem;
  final RunnerSettings? thisDeviceSettings;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'summary': summary.toJson(),
      'summary_text': summaryText,
      'runners': encodeList(runners),
      'this_device_problem': thisDeviceProblem,
      'this_device_settings': thisDeviceSettings?.toJson(),
    };
  }
}
