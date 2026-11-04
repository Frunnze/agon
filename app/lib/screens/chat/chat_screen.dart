import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/shared/live_run_watch.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    required this.runId,
    required this.taskRepository,
    required this.workflowRepository,
    required this.chatRepository,
    required this.runnerRepository,
    required this.deviceRepository,
    required this.navigation,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final ChatRepository chatRepository;
  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final AppNavigation navigation;

  ChatRunContext _readRunContext() {
    final Run run = taskRepository.findRun(runId);
    final Task task = taskRepository.findTask(run.taskId);

    return ChatRunContext(
      run: run,
      task: task,
      workflow: findWorkflowForDoer(
        task.doer,
        workflowRepository.listWorkflows(),
      ),
      deviceNames: DeviceNames(deviceRepository.listDevices()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveRunWatch(
      runId: runId,
      taskRepository: taskRepository,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          taskRepository,
          chatRepository,
          runnerRepository,
          deviceRepository,
        ]),
        builder: _buildPage,
      ),
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final ChatRunContext runContext = _readRunContext();
    final DeviceId? runnerId = runContext.runnerId;

    return ChatPageLayout(
      runContext: runContext,
      conversation: chatRepository.findConversation(runId),
      runner: runnerId == null ? null : runnerRepository.findRunner(runnerId),
      thisDevice: deviceRepository.currentDevice(),
      onBack: _returnToRun,
      onSend: _sendMessage,
    );
  }

  void _returnToRun() {
    navigation.returnTo(TaskRunRoute(runId));
  }

  Future<void> _sendMessage(String text) async {
    await chatRepository.sendMessage(runId, text);
  }
}
