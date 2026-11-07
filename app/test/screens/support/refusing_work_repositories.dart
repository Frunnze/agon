import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

import 'planned_refusal.dart';

final class RefusingTaskRepository implements TaskRepository {
  RefusingTaskRepository({required this.stored, required this.refusal});

  final TaskRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Task> listTasks() => stored.listTasks();

  @override
  Task findTask(TaskId taskId) => stored.findTask(taskId);

  @override
  List<Run> listRuns(TaskId taskId) => stored.listRuns(taskId);

  @override
  Run findRun(RunId runId) => stored.findRun(runId);

  @override
  Future<Task> createTask(TaskDraft draft) {
    return refusal.refuseOr(() => stored.createTask(draft));
  }

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    return stored.updateTask(taskId, draft);
  }

  @override
  Future<Run> startTask(TaskId taskId) => stored.startTask(taskId);

  @override
  Future<Run> cancelRun(RunId runId) {
    return refusal.refuseOr(() => stored.cancelRun(runId));
  }

  @override
  Future<Run> retryRun(RunId runId) => stored.retryRun(runId);

  @override
  Future<void> deleteTask(TaskId taskId) => stored.deleteTask(taskId);

  @override
  void watchRun(RunId runId) => stored.watchRun(runId);

  @override
  void stopWatchingRun(RunId runId) => stored.stopWatchingRun(runId);
}

final class RefusingChatRepository implements ChatRepository {
  RefusingChatRepository({required this.stored, required this.refusal});

  final ChatRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  Conversation findConversation(RunId runId) {
    return stored.findConversation(runId);
  }

  @override
  Future<ChatMessage> sendMessage(RunId runId, String text) {
    return refusal.refuseOr(() => stored.sendMessage(runId, text));
  }
}

final class RefusingApprovalRepository implements ApprovalRepository {
  RefusingApprovalRepository({required this.stored, required this.refusal});

  final ApprovalRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<ApprovalRequest> listApprovals() => stored.listApprovals();

  @override
  List<ApprovalRequest> listPendingApprovals() {
    return stored.listPendingApprovals();
  }

  @override
  ApprovalRequest findApproval(ApprovalId approvalId) {
    return stored.findApproval(approvalId);
  }

  @override
  Future<ApprovalRequest> decideApproval(
    ApprovalId approvalId,
    ApprovalDecision decision,
  ) {
    return refusal.refuseOr(() => stored.decideApproval(approvalId, decision));
  }
}

final class RefusingRunnerRepository implements RunnerRepository {
  RefusingRunnerRepository({required this.stored, required this.refusal});

  final RunnerRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Runner> listRunners() => stored.listRunners();

  @override
  Runner findRunner(DeviceId deviceId) => stored.findRunner(deviceId);

  @override
  Future<Runner> pauseRunner(DeviceId deviceId) {
    return refusal.refuseOr(() => stored.pauseRunner(deviceId));
  }

  @override
  Future<Runner> resumeRunner(DeviceId deviceId) {
    return refusal.refuseOr(() => stored.resumeRunner(deviceId));
  }

  @override
  List<PlaceOffer>? findThisDeviceOffers() => stored.findThisDeviceOffers();

  @override
  String? findThisRunnerProblem() => stored.findThisRunnerProblem();

  @override
  Future<void> chooseAgentOffers(List<AgentPlace> offers) {
    return refusal.refuseOr(() => stored.chooseAgentOffers(offers));
  }
}

final class RefusingAgentLoginRepository implements AgentLoginRepository {
  RefusingAgentLoginRepository({required this.stored, required this.refusal});

  final AgentLoginRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  AgentLoginStatus? findStatus() => stored.findStatus();

  @override
  LoginTerminal? findTerminal() => stored.findTerminal();

  @override
  Future<void> checkStatus() => stored.checkStatus();

  @override
  Future<void> openTerminal(AgentPlace place) {
    return refusal.refuseOr(() => stored.openTerminal(place));
  }

  @override
  Future<void> typeIntoTerminal(String keys) {
    return refusal.refuseOr(() => stored.typeIntoTerminal(keys));
  }

  @override
  Future<void> closeTerminal() {
    return refusal.refuseOr(stored.closeTerminal);
  }

  @override
  Future<void> saveApiKey(String apiKey) {
    return refusal.refuseOr(() => stored.saveApiKey(apiKey));
  }

  @override
  Future<void> forgetCredential() {
    return refusal.refuseOr(stored.forgetCredential);
  }
}
