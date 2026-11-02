import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const String _listSeparator = ', ';
const String _lastSeparator = ' and ';

final class DraftProgressLine {
  const DraftProgressLine({required this.text, required this.isDone});

  final String text;
  final bool isDone;
}

String joinNamesInProse(List<String> names) {
  if (names.length < 2) {
    return names.join();
  }

  final List<String> leading = names.sublist(0, names.length - 1);
  return '${leading.join(_listSeparator)}$_lastSeparator${names.last}';
}

String describeAddedAgent({
  required WorkflowAgent agent,
  required DeviceNames deviceNames,
  required List<Skill> skills,
}) {
  final String kind = describeAgentKind(agent.kind);
  final String target = describeAgentTarget(agent.runsOn, deviceNames);
  final List<String> skillNames = describeSkillNames(
    skills: skills,
    skillIds: agent.skills,
  );
  final String added = 'Added ${agent.name}, $kind on $target';

  if (skillNames.isEmpty) {
    return added;
  }
  return '$added with ${joinNamesInProse(skillNames)}';
}

List<DraftProgressLine> describeDraftProgress({
  required WorkflowDraftProgress? progress,
  required DeviceNames deviceNames,
  required List<Skill> skills,
}) {
  if (progress == null) {
    return const <DraftProgressLine>[
      DraftProgressLine(text: 'Reading your description', isDone: false),
    ];
  }

  final List<String> pendingNames = <String>[
    for (final PendingAgent pending in progress.pendingAgents) pending.name,
  ];
  return <DraftProgressLine>[
    const DraftProgressLine(text: 'Read your description', isDone: true),
    for (final WorkflowAgent agent in progress.workflow.agents)
      DraftProgressLine(
        text: describeAddedAgent(
          agent: agent,
          deviceNames: deviceNames,
          skills: skills,
        ),
        isDone: true,
      ),
    if (pendingNames.isNotEmpty)
      DraftProgressLine(
        text: 'Adding ${joinNamesInProse(pendingNames)}',
        isDone: false,
      ),
  ];
}

String describeDrafter({
  required WorkflowDraftProgress? progress,
  required DeviceNames deviceNames,
}) {
  if (progress == null) {
    return 'Starting the draft';
  }

  final String device = deviceNames.nameOf(progress.drafterDeviceId);
  return '${progress.drafterKind.label} is drafting on $device';
}

class DraftProgressPanel extends StatelessWidget {
  const DraftProgressPanel({required this.lines, super.key});

  final List<DraftProgressLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        Semantics(
          header: true,
          child: const Text('Draft progress', style: AppTextStyles.bodyBold),
        ),
        for (final DraftProgressLine line in lines)
          StatusLabel(
            text: line.text,
            tone: line.isDone ? StatusTone.muted : StatusTone.normal,
            icon: line.isDone ? AppIconKind.check : AppIconKind.spinner,
          ),
      ], AppSpacing.space3),
    );
  }
}
