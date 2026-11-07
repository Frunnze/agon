import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/approval_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/memory_workspace_choice_store.dart';
import 'support/host_account_harness.dart';

const Duration _retryDelay = Duration(milliseconds: 200);
const Duration _waitStep = Duration(milliseconds: 100);
const Duration _waitLimit = Duration(seconds: 20);
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));
const String _chatText = 'Please also check the header.';
const String _deployTarget = 'staging';

Future<void> _waitUntil(bool Function() isReached) async {
  final DateTime deadline = DateTime.now().add(_waitLimit);
  while (!isReached()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('the change feed did not deliver in time');
    }
    await Future<void>.delayed(_waitStep);
  }
}

TaskDraft _buildFooterTask(ProjectId projectId) {
  return TaskDraft(
    title: 'Fix the footer',
    details: 'Keep it small.',
    projectId: projectId,
    doer: const OneAgentDoer(AgentKind.claudeCode),
    runsOn: const AnyFreeRunner(),
    agentPlace: AgentPlace.localProcess,
    skills: const <SkillId>[],
    usesAutomaticSkills: false,
    approvalPolicy: ApprovalPolicy.askBeforeRiskyActions,
  );
}

void main() {
  final String? skipReason = findHostLibrarySkipReason();

  test(
    'test_node_backed_work_property_task_reaches_chat_and_approvals',
    () async {
      final HostAccount host = await openHostAccount(
        repositories: const <node.Repository>[],
      );
      final NodeCommandChannel channel = host.channel;
      final node.Project project = host.project;

      final NodeBackedWorkspaceRepository workspaces =
          NodeBackedWorkspaceRepository(
            channel: channel,
            clock: const SystemClock(),
            retryInterval: _retryDelay,
            choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
          );
      final NodeBackedTaskRepository tasks = NodeBackedTaskRepository(
        clock: const SystemClock(),
        channel: channel,
        workspaceRepository: workspaces,
        livePollInterval: _retryDelay,
        jobRepository: NodeBackedJobRepository(
          channel: channel,
          workspaceRepository: workspaces,
          clock: const SystemClock(),
        ),
      );
      final NodeBackedChatRepository chat = NodeBackedChatRepository(
        channel: channel,
        runSource: tasks,
        workspaceRepository: workspaces,
      );
      final NodeBackedApprovalRepository approvals =
          NodeBackedApprovalRepository(channel: channel);
      final NodeSynchronization synchronization = NodeSynchronization(
        channel: channel,
        repositoriesInLoadOrder: <NodeSynchronized>[
          workspaces,
          tasks,
          approvals,
        ],
        retryDelay: _retryDelay,
        recheckAppServer: workspaces.retryAppServer,
      );
      await synchronization.start();
      addTearDown(synchronization.stop);
      expect(tasks.listTasks(), isEmpty);

      final Task created = await tasks.createTask(
        _buildFooterTask(project.id),
      );
      expect(tasks.listTasks().single.id, created.id);
      expect(tasks.findTask(created.id).status, TaskStatus.toDo);

      final Run run = await tasks.startTask(created.id);
      expect(tasks.listRuns(created.id).single.id, run.id);
      expect(tasks.findRun(run.id).status, RunStatus.queued);
      expect(tasks.findTask(created.id).status, TaskStatus.running);

      final ChatMessage sent = await chat.sendMessage(run.id, _chatText);
      expect(sent.author, ChatAuthor.you);
      expect(chat.findConversation(run.id).messages.last.text, _chatText);

      expect(approvals.listPendingApprovals(), isEmpty);
      await channel.execute(
        const node.CreateApprovalCommand(
          runId: null,
          action: node.Deploy(target: _deployTarget),
        ),
      );
      await _waitUntil(() => approvals.listPendingApprovals().isNotEmpty);
      final ApprovalRequest pending = approvals.listPendingApprovals().single;
      expect(pending.runId, isNull);
      expect((pending.action as DeployAction).target, _deployTarget);

      final ApprovalRequest decided = await approvals.decideApproval(
        pending.id,
        ApprovalDecision.approved,
      );
      expect(decided.decision?.decision, ApprovalDecision.approved);
      expect(approvals.listPendingApprovals(), isEmpty);
      expect(approvals.listApprovals().single.id, pending.id);
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );
}
