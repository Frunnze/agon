import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

class LiveRunWatch extends StatefulWidget {
  const LiveRunWatch({
    required this.runId,
    required this.taskRepository,
    required this.child,
    super.key,
  });

  final RunId runId;
  final TaskRepository taskRepository;
  final Widget child;

  @override
  State<LiveRunWatch> createState() => _LiveRunWatchState();
}

class _LiveRunWatchState extends State<LiveRunWatch> {
  @override
  void initState() {
    super.initState();
    widget.taskRepository.watchRun(widget.runId);
  }

  @override
  void didUpdateWidget(LiveRunWatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runId == widget.runId) {
      return;
    }
    oldWidget.taskRepository.stopWatchingRun(oldWidget.runId);
    widget.taskRepository.watchRun(widget.runId);
  }

  @override
  void dispose() {
    widget.taskRepository.stopWatchingRun(widget.runId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
