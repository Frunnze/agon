import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

const String startNowLabel = 'Start now';
const String quickStartTitleStart = 'Run ';
const String _noDetails = '';

TaskDraft buildQuickStartTask({
  required Workflow workflow,
  required ProjectId projectId,
}) {
  return TaskDraft(
    title: '$quickStartTitleStart${workflow.name}',
    details: _noDetails,
    projectId: projectId,
    doer: WorkflowDoer(workflow.id),
    runsOn: const AnyFreeRunner(),
    agentPlace: defaultAgentPlace,
    skills: const <SkillId>[],
    usesAutomaticSkills: true,
    approvalPolicy: null,
  );
}

Future<RunId> startWorkflowNow({
  required TaskRepository taskRepository,
  required Workflow workflow,
  required ProjectId projectId,
}) async {
  final TaskDraft draft = buildQuickStartTask(
    workflow: workflow,
    projectId: projectId,
  );
  final Task task = await taskRepository.createTask(draft);
  final Run run = await taskRepository.startTask(task.id);
  return run.id;
}
