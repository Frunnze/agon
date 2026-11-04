import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

final class ListDevicesCommand implements NodeCommand<List<DeviceView>> {
  const ListDevicesCommand();

  @override
  String get name => 'list_devices';

  @override
  JsonObject get arguments => noArguments;

  @override
  List<DeviceView> decodeReply(Object? okValue) {
    return decodeList(okValue, DeviceView.fromJson);
  }
}

final class RevokeDeviceCommand implements NodeCommand<void> {
  const RevokeDeviceCommand({required this.deviceId});

  final DeviceId deviceId;

  @override
  String get name => 'revoke_device';

  @override
  JsonObject get arguments => <String, Object?>{'device_id': deviceId.value};

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ListWorkspacesCommand implements NodeCommand<List<WorkspaceView>> {
  const ListWorkspacesCommand();

  @override
  String get name => 'list_workspaces';

  @override
  JsonObject get arguments => noArguments;

  @override
  List<WorkspaceView> decodeReply(Object? okValue) {
    return decodeList(okValue, WorkspaceView.fromJson);
  }
}

final class CreateWorkspaceCommand implements NodeCommand<Workspace> {
  const CreateWorkspaceCommand({required this.workspaceName});

  final String workspaceName;

  @override
  String get name => 'create_workspace';

  @override
  JsonObject get arguments => <String, Object?>{'name': workspaceName};

  @override
  Workspace decodeReply(Object? okValue) => Workspace.fromJson(okValue);
}

final class SetProtectedFilesCommand implements NodeCommand<Workspace> {
  SetProtectedFilesCommand({
    required this.workspaceId,
    required List<String> patterns,
  }) : patterns = List<String>.unmodifiable(patterns);

  final WorkspaceId workspaceId;
  final List<String> patterns;

  @override
  String get name => 'set_protected_files';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'patterns': patterns,
    };
  }

  @override
  Workspace decodeReply(Object? okValue) => Workspace.fromJson(okValue);
}

final class ResetProtectedFilesCommand implements NodeCommand<Workspace> {
  const ResetProtectedFilesCommand({required this.workspaceId});

  final WorkspaceId workspaceId;

  @override
  String get name => 'reset_protected_files';

  @override
  JsonObject get arguments => <String, Object?>{
    'workspace_id': workspaceId.value,
  };

  @override
  Workspace decodeReply(Object? okValue) => Workspace.fromJson(okValue);
}

final class ChangeWorkspaceApprovalPolicyCommand
    implements NodeCommand<Workspace> {
  const ChangeWorkspaceApprovalPolicyCommand({
    required this.workspaceId,
    required this.approvalPolicy,
  });

  final WorkspaceId workspaceId;
  final ApprovalPolicy approvalPolicy;

  @override
  String get name => 'change_workspace_approval_policy';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'approval_policy': approvalPolicy.wireName,
    };
  }

  @override
  Workspace decodeReply(Object? okValue) => Workspace.fromJson(okValue);
}

final class AddDeviceToWorkspaceCommand implements NodeCommand<void> {
  const AddDeviceToWorkspaceCommand({
    required this.workspaceId,
    required this.deviceId,
  });

  final WorkspaceId workspaceId;
  final DeviceId deviceId;

  @override
  String get name => 'add_device_to_workspace';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'device_id': deviceId.value,
    };
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class RemoveDeviceFromWorkspaceCommand implements NodeCommand<void> {
  const RemoveDeviceFromWorkspaceCommand({
    required this.workspaceId,
    required this.deviceId,
  });

  final WorkspaceId workspaceId;
  final DeviceId deviceId;

  @override
  String get name => 'remove_device_from_workspace';

  @override
  JsonObject get arguments {
    return <String, Object?>{
      'workspace_id': workspaceId.value,
      'device_id': deviceId.value,
    };
  }

  @override
  void decodeReply(Object? okValue) => decodeNothing(okValue);
}

final class ListAuditCommand implements NodeCommand<AuditView> {
  const ListAuditCommand();

  @override
  String get name => 'list_audit';

  @override
  JsonObject get arguments => noArguments;

  @override
  AuditView decodeReply(Object? okValue) => AuditView.fromJson(okValue);
}
