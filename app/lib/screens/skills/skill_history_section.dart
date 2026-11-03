import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';
import 'package:agent_orchestration/presentation/skill_history_text.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class SkillHistorySection extends StatelessWidget {
  const SkillHistorySection({
    required this.history,
    required this.taskRepository,
    required this.workflows,
    required this.now,
    required this.onUndo,
    super.key,
  });

  final List<SkillChange> history;
  final TaskRepository taskRepository;
  final List<Workflow> workflows;
  final DateTime now;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final List<SkillChange> recentChanges = listRecentSkillChanges(history);
    final SkillChange? undoableChange = findUndoableAgentChange(history);

    return PageSection(
      title: 'History',
      children: <Widget>[
        if (recentChanges.isEmpty)
          const MutedNote('No changes yet.')
        else
          ResponsiveList.plain(
            rows: <ListRowData>[
              for (final SkillChange change in recentChanges)
                _buildRow(
                  change: change,
                  end: identical(change, undoableChange)
                      ? AppButton.secondary(label: 'Undo', onPressed: onUndo)
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  ListRowData _buildRow({required SkillChange change, required Widget? end}) {
    final String moment = describeSkillChangeMoment(
      runLabel: _findChangeRunLabel(change.origin),
      savedAt: change.savedAt,
      now: now,
    );

    return ListRowData(
      key: ObjectKey(change),
      main: ListRowMain(
        title: describeSkillChangeTitle(change.origin),
        subtitle: <TextSegment>[TextSegment(moment)],
      ),
      end: end,
    );
  }

  String? _findChangeRunLabel(SkillChangeOrigin origin) {
    return switch (origin) {
      PersonEdit() => null,
      AgentRunOrigin(:final RunId runId) => findRunLabel(
        runId: runId,
        taskRepository: taskRepository,
        workflows: workflows,
      ),
    };
  }
}
