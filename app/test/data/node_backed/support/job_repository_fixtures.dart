import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/sample_records.dart' show randomJobSchedule;
import 'node_backed_harness.dart';
import 'simulated_work_node.dart';

const int _largestOutsideCount = 6;

typedef JobFixture = ({
  SimulatedWorkNode node,
  NodeBackedJobRepository repository,
  List<Map<String, Object?>> sentCommands,
});

final class _RecordingNode {
  _RecordingNode(this.node);

  final SimulatedWorkNode node;
  final List<Map<String, Object?>> sentCommands = <Map<String, Object?>>[];

  String answer(String inputJson) {
    sentCommands.add(jsonDecode(inputJson) as Map<String, Object?>);
    return node.answer(inputJson);
  }
}

JobFixture buildJobFixture(DateTime moment) {
  final _RecordingNode recording = _RecordingNode(
    SimulatedWorkNode(thisDeviceId: 'me'),
  );
  return (
    node: recording.node,
    repository: NodeBackedJobRepository(
      channel: buildSimulatedChannel(recording.answer),
      workspaceRepository: buildSingleWorkspaceRepository(),
      clock: FixedClock(moment),
    ),
    sentCommands: recording.sentCommands,
  );
}

JobDraft randomSimulatedJobDraft(Random random) {
  return JobDraft(
    task: randomTaskDraft(random),
    schedule: randomJobSchedule(random),
  );
}

void addOutsideWork(Random random, SimulatedWorkNode simulated) {
  final int count = random.nextInt(_largestOutsideCount + 1);
  for (int i = 0; i < count; i += 1) {
    simulated.addTaskFromElsewhere(random);
  }
}

Set<String> listSimulatedJobIds(SimulatedWorkNode simulated) {
  return <String>{
    for (final WireRecord task in simulated.tasks.values)
      if (isJob(task)) task['id']! as String,
  };
}

Set<String> listRepositoryJobIds(NodeBackedJobRepository repository) {
  return <String>{for (final Task job in repository.listJobs()) job.id.value};
}
