import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import 'random_inputs.dart';

Runner randomRunner(Random random) {
  final Runner base = pickOne(random, galleryRunners);
  final int slotsTotal = random.nextInt(5);

  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: slotsTotal,
    slotsBusy: slotsTotal == 0 ? 0 : random.nextInt(slotsTotal + 1),
    link: pickOne(random, RunnerLink.values),
    online: random.nextBool(),
    acceptingNewRuns: random.nextBool(),
    sandbox: pickOne(random, SandboxKind.values),
    allowedHosts: base.allowedHosts,
  );
}

List<Runner> randomRunners(Random random) {
  return <Runner>[
    for (int index = 0; index < random.nextInt(6); index += 1)
      randomRunner(random),
  ];
}
