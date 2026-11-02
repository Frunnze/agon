import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/runner_target_text.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _anyFreeRunnerLabel = 'Any free runner';

final class TaskFormOptions {
  TaskFormOptions({
    required List<SelectOption<ProjectId>> projects,
    required List<SelectEntry<TaskDoer>> doers,
    required List<SelectOption<RunnerTarget>> runners,
    required List<Skill> skills,
    required Map<ProjectId, MissingFolderRunner> missingFolderRunners,
  }) : projects = List<SelectOption<ProjectId>>.unmodifiable(projects),
       doers = List<SelectEntry<TaskDoer>>.unmodifiable(doers),
       runners = List<SelectOption<RunnerTarget>>.unmodifiable(runners),
       skills = List<Skill>.unmodifiable(skills),
       missingFolderRunners = Map<ProjectId, MissingFolderRunner>.unmodifiable(
         missingFolderRunners,
       );

  final List<SelectOption<ProjectId>> projects;
  final List<SelectEntry<TaskDoer>> doers;
  final List<SelectOption<RunnerTarget>> runners;
  final List<Skill> skills;
  final Map<ProjectId, MissingFolderRunner> missingFolderRunners;

  ProjectId get firstProjectId {
    if (projects.isEmpty) {
      throw StateError('Create a project before adding tasks');
    }
    return projects.first.value;
  }

  List<String> describeSkills(List<SkillId> skillIds) {
    return describeSkillNames(skills: skills, skillIds: skillIds);
  }

  SkillId findSkillId(String skillName) {
    return findSkillIdByName(skills: skills, skillName: skillName);
  }
}

List<SelectEntry<TaskDoer>> _buildDoerEntries(List<Workflow> workflows) {
  return <SelectEntry<TaskDoer>>[
    const SelectGroupHeading<TaskDoer>('One agent'),
    for (final AgentKind agent in AgentKind.values)
      SelectOption<TaskDoer>(value: OneAgentDoer(agent), label: agent.label),
    const SelectGroupHeading<TaskDoer>('A workflow'),
    for (final Workflow workflow in workflows)
      if (workflow.signature == null)
        SelectOption<TaskDoer>.disabled(
          value: WorkflowDoer(workflow.id),
          label: '${workflow.name}, not signed yet',
        )
      else
        SelectOption<TaskDoer>(
          value: WorkflowDoer(workflow.id),
          label: workflow.name,
        ),
  ];
}

String _describeTargetLabel(RunnerTarget target, DeviceNames deviceNames) {
  if (target is AnyFreeRunner) {
    return _anyFreeRunnerLabel;
  }
  final List<TextSegment> segments = describeRunnerTarget(target, deviceNames);

  return segments.map((TextSegment segment) => segment.text).join();
}

List<SelectOption<RunnerTarget>> buildRunnerOptions({
  required List<Runner> runners,
  required DeviceNames deviceNames,
  required RunnerTarget chosenTarget,
}) {
  final List<RunnerTarget> targets = <RunnerTarget>[const AnyFreeRunner()];
  for (final Runner runner in runners) {
    if (runner.online) {
      targets.add(SpecificRunner(runner.deviceId));
    }
  }
  if (!targets.contains(chosenTarget)) {
    targets.add(chosenTarget);
  }

  return <SelectOption<RunnerTarget>>[
    for (final RunnerTarget target in targets)
      SelectOption<RunnerTarget>(
        value: target,
        label: _describeTargetLabel(target, deviceNames),
      ),
  ];
}

TaskFormOptions buildTaskFormOptions({
  required List<Project> projects,
  required List<Workflow> workflows,
  required List<Runner> runners,
  required DeviceNames deviceNames,
  required List<Skill> skills,
  required RunnerTarget chosenTarget,
}) {
  return TaskFormOptions(
    projects: <SelectOption<ProjectId>>[
      for (final Project project in projects)
        SelectOption<ProjectId>(value: project.id, label: project.name),
    ],
    doers: _buildDoerEntries(workflows),
    runners: buildRunnerOptions(
      runners: runners,
      deviceNames: deviceNames,
      chosenTarget: chosenTarget,
    ),
    skills: skills,
    missingFolderRunners: _findMissingFolderRunners(
      projects: projects,
      runners: runners,
      deviceNames: deviceNames,
    ),
  );
}

Map<ProjectId, MissingFolderRunner> _findMissingFolderRunners({
  required List<Project> projects,
  required List<Runner> runners,
  required DeviceNames deviceNames,
}) {
  final Map<ProjectId, MissingFolderRunner> missingRunners =
      <ProjectId, MissingFolderRunner>{};
  for (final Project project in projects) {
    final MissingFolderRunner? missing = findMissingFolderRunner(
      project: project,
      runners: runners,
      deviceNames: deviceNames,
    );
    if (missing != null) {
      missingRunners[project.id] = missing;
    }
  }
  return missingRunners;
}
