import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

final RegExp sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp deviceIdentifierPattern = RegExp(r'^[0-9a-f]{32}$');

final List<Task> galleryWork = List<Task>.unmodifiable(<Task>[
  ...galleryTasks,
  ...galleryJobs,
]);

bool hasNoRepeats<T>(Iterable<T> values) {
  return values.toSet().length == values.length;
}

Device findGalleryDevice(DeviceId deviceId) {
  return findRecord(
    galleryDevices,
    matches: (Device device) => device.id == deviceId,
    kind: 'device',
    identifier: deviceId.value,
  );
}

Project findGalleryProject(ProjectId projectId) {
  return findRecord(
    galleryProjects,
    matches: (Project project) => project.id == projectId,
    kind: 'project',
    identifier: projectId.value,
  );
}

Workspace findGalleryWorkspace(WorkspaceId workspaceId) {
  return findRecord(
    galleryWorkspaces,
    matches: (Workspace workspace) => workspace.id == workspaceId,
    kind: 'workspace',
    identifier: workspaceId.value,
  );
}

Task findGalleryWork(TaskId taskId) {
  return findRecord(
    galleryWork,
    matches: (Task task) => task.id == taskId,
    kind: 'task',
    identifier: taskId.value,
  );
}

Workflow findGalleryWorkflow(WorkflowId workflowId) {
  return findRecord(
    galleryWorkflows,
    matches: (Workflow workflow) => workflow.id == workflowId,
    kind: 'workflow',
    identifier: workflowId.value,
  );
}
