import 'dart:math';

import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
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
    offers: <AgentPlace>[
      for (final AgentPlace place in AgentPlace.values)
        if (random.nextBool()) place,
    ],
    allowedHosts: base.allowedHosts,
  );
}

List<Runner> randomRunners(Random random) {
  return <Runner>[
    for (int index = 0; index < random.nextInt(6); index += 1)
      randomRunner(random),
  ];
}

Runner buildOnlineRunnerOn(DeviceId deviceId) {
  final Runner base = galleryRunners.first;
  return Runner(
    deviceId: deviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: 0,
    link: RunnerLink.direct,
    online: true,
    acceptingNewRuns: true,
    offers: AgentPlace.values,
    allowedHosts: base.allowedHosts,
  );
}
