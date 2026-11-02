import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../support/app_harness.dart';

const List<AppRoute> _runPages = <AppRoute>[
  TaskRunRoute(GalleryRunIds.release42),
  ChatRoute(GalleryRunIds.release42),
];

DeviceId _findCurrentRunner() {
  final Run run = buildGalleryDependencies().taskRepository.findRun(
    GalleryRunIds.release42,
  );
  return findCurrentStep(run).runner!;
}

void main() {
  testWidgets('test_run_pages_property_route_line_only_to_another_computer', (
    WidgetTester tester,
  ) async {
    final DeviceId runner = _findCurrentRunner();

    for (final AppRoute route in _runPages) {
      for (final DeviceId thisDevice in <DeviceId>[
        runner,
        GalleryDeviceIds.airLaptop,
      ]) {
        await pumpApp(
          tester,
          size: desktopSize,
          route: route,
          dependencies: replaceRepositories(
            buildGalleryDependencies(),
            deviceRepository: FakeDeviceRepository(
              devices: galleryDevices,
              currentDeviceId: thisDevice,
              peerAddressProblem: null,
            ),
          ),
        );

        final bool isSameComputer = thisDevice == runner;
        expect(
          find.byType(RouteLine).evaluate().isEmpty,
          isSameComputer,
          reason: '$route on ${thisDevice.value}',
        );
      }
    }
  });
}
