import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/windows/app_window_list.dart';
import 'package:agent_orchestration/windows/native_windows.dart';
import 'package:agent_orchestration/windows/run_window_app.dart';

import 'app_harness.dart';
import 'widget_harness.dart';

AppDependencies removeApprovals(AppDependencies base) {
  return replaceRepositories(
    base,
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
}

Future<AppNavigation> pumpRunWindow(
  WidgetTester tester, {
  required RunId runId,
  required AppDependencies dependencies,
  required OnTopSwitch onTopSwitch,
}) async {
  final AppNavigation navigation = AppNavigation.limitedToRunPages(
    runId: runId,
  );
  useViewSize(tester, runWindowSize);
  await tester.pumpWidget(
    RunWindowApp(
      key: UniqueKey(),
      navigation: navigation,
      dependencies: dependencies,
      onTopSwitch: onTopSwitch,
      messengerKey: GlobalKey<ScaffoldMessengerState>(),
    ),
  );
  await pumpFrames(tester);
  return navigation;
}
