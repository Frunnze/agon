import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_views.dart';
import 'package:agent_orchestration/bridge/codecs/audit_values.dart';
import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_views.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/approval_commands.dart';
import 'package:agent_orchestration/bridge/commands/device_commands.dart';
import 'package:agent_orchestration/bridge/commands/library_commands.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/bridge/commands/runner_commands.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

const Scope _everywhere = Scope(
  workspaces: AllWorkspaces(),
  projects: AllProjects(),
);
const EveryDay _everyNight = EveryDay(at: ScheduleTime(hour: 2, minute: 0));

Future<void> expectNodeCatalogFlow({
  required NodeCommandChannel channel,
  required WorkspaceId workspaceId,
  required DeviceId deviceId,
}) async {
  final Project project = await _expectProjectListed(channel, workspaceId);
  await _expectLibraryListed(channel, workspaceId, project.id);
  await _expectWorkListed(channel, workspaceId, project.id);

  final List<DeviceView> devices = await channel.execute(
    const ListDevicesCommand(),
  );
  final RunnersView runners = await channel.execute(
    ListRunnersCommand(workspaceId: workspaceId),
  );
  final ApprovalsView approvals = await channel.execute(
    const ListApprovalsCommand(),
  );
  final AuditView audit = await channel.execute(const ListAuditCommand());

  expect(devices.single.device.id, deviceId);
  expect(devices.single.isThisDevice, isTrue);
  expect(runners.runners, isEmpty);
  expect(approvals.waitingCount, 0);
  expect(audit.intact, isTrue);
  expect(audit.entries.length, audit.entryCount);
}

Future<Project> _expectProjectListed(
  NodeCommandChannel channel,
  WorkspaceId workspaceId,
) async {
  final Project project = await channel.execute(
    CreateProjectCommand(
      workspaceId: workspaceId,
      projectName: 'website',
      repositories: const <Repository>[
        Repository(
          address: 'https://github.com/example/site.git',
          defaultBranch: 'main',
          agentAccess: AgentAccess.readOnly,
        ),
      ],
      approvalPolicy: null,
    ),
  );
  final List<ProjectView> projects = await channel.execute(
    ListProjectsCommand(workspaceId: workspaceId),
  );

  expect(project.repositories.single.address, 'github.com/example/site');
  expect(projects.single.project.id, project.id);
  expect(projects.single.taskCount, 0);
  return project;
}

Future<void> _expectLibraryListed(
  NodeCommandChannel channel,
  WorkspaceId workspaceId,
  ProjectId projectId,
) async {
  final Rule rule = await channel.execute(
    CreateRuleCommand(
      workspaceId: workspaceId,
      title: 'Run the tests',
      details: 'Before every push.',
      scope: _everywhere,
    ),
  );
  final Skill skill = await channel.execute(
    CreateSkillCommand(
      workspaceId: workspaceId,
      skillName: 'code-review',
      summary: 'Reviews a change.',
      instructions: 'Read the diff first.',
      scope: _everywhere,
      usage: SkillUsage.whenChosen,
      improvement: SkillImprovement.askMe,
    ),
  );
  final List<Rule> rules = await channel.execute(
    ListRulesCommand(workspaceId: workspaceId),
  );
  final List<Skill> skills = await channel.execute(
    ListSkillsCommand(workspaceId: workspaceId),
  );
  final AgentsMarkdownView agentsMarkdown = await channel.execute(
    ShowAgentsMarkdownCommand(workspaceId: workspaceId, projectId: projectId),
  );

  expect(rules.single.id, rule.id);
  expect(rules.single.details, 'Before every push.');
  expect(skills.single.id, skill.id);
  expect(skills.single.instructions, 'Read the diff first.');
  expect(skills.single.improvement, SkillImprovement.askMe);
  expect(skills.single.history, isEmpty);
  expect(agentsMarkdown.markdown, contains('Run the tests'));
}

Future<void> _expectWorkListed(
  NodeCommandChannel channel,
  WorkspaceId workspaceId,
  ProjectId projectId,
) async {
  final Task task = await channel.execute(
    CreateTaskCommand(
      task: _buildTaskArguments(workspaceId, projectId, 'Fix the footer'),
      start: TaskStart.later,
    ),
  );
  final Task job = await channel.execute(
    CreateJobCommand(
      task: _buildTaskArguments(workspaceId, projectId, 'Nightly checks'),
      schedule: _everyNight,
    ),
  );
  final TasksView tasks = await channel.execute(
    ListTasksCommand(workspaceId: workspaceId),
  );
  final List<JobView> jobs = await channel.execute(
    ListJobsCommand(workspaceId: workspaceId),
  );

  expect(tasks.tasks.single.task.id, task.id);
  expect(tasks.tasks.single.projectName, 'website');
  expect(tasks.summary.toDo, 1);
  expect(jobs.single.task.id, job.id);
  expect(jobs.single.scheduleDescription, 'Every day at 02:00');
}

TaskArguments _buildTaskArguments(
  WorkspaceId workspaceId,
  ProjectId projectId,
  String title,
) {
  return TaskArguments(
    workspaceId: workspaceId,
    projectId: projectId,
    title: title,
    details: 'Keep it small.',
    doer: const OneAgent(agent: AgentKind.claudeCode),
    runsOn: const AnyFreeRunner(),
    agentPlace: AgentPlace.localProcess,
    skills: const <SkillId>[],
    usesAutomaticSkills: false,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
  );
}
