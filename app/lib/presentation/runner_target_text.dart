import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

List<TextSegment> describeRunnerTarget(
  RunnerTarget target,
  DeviceNames deviceNames,
) {
  switch (target) {
    case AnyFreeRunner():
      return const <TextSegment>[TextSegment('Any runner')];
    case SpecificRunner():
      return <TextSegment>[
        TextSegment.monospace(deviceNames.nameOf(target.deviceId)),
      ];
    case RunnerWithLabels():
      return <TextSegment>[
        const TextSegment('Any runner with '),
        TextSegment.monospace(target.labels.join(', ')),
      ];
  }
}
