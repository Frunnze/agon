import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class RunLogSection extends StatelessWidget {
  const RunLogSection({
    required this.run,
    required this.deviceNames,
    required this.thisDevice,
    super.key,
  });

  final Run run;
  final DeviceNames deviceNames;
  final Device thisDevice;

  @override
  Widget build(BuildContext context) {
    final RunStep currentStep = findCurrentStep(run);
    final DeviceId? runner = currentStep.runner;
    final bool isActive = isRunActive(run);
    final List<LogBlockLine> lines = <LogBlockLine>[
      for (final LogLine line in run.log)
        if (line.stepName == currentStep.name)
          LogBlockLine(
            time: formatLogTime(line.at),
            text: line.text,
            tone: line.isError ? LineTone.danger : LineTone.normal,
          ),
    ];

    return PageSection(
      title: '${currentStep.name} log',
      children: <Widget>[
        if (isActive && runner != null && runner != thisDevice.id)
          buildRunnerLinkRoute(
            startName: deviceNames.nameOf(runner),
            endName: thisDevice.name,
            link: run.link,
          ),
        if (lines.isEmpty)
          const Text('Nothing logged yet.', style: AppTextStyles.smallMuted)
        else
          LogBlock(
            lines: lines,
            cursor: isActive
                ? CursorVisibility.shown
                : CursorVisibility.hidden,
          ),
      ],
    );
  }
}
