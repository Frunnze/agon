import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('test_approval_dialog_property_local_repo_named_by_folder', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final String address = renderLocalFolderAddress(
        deviceId: device.id,
        path: '/Users/someone/code/hello-counter-$i',
      );
      final ApprovalRequest request = ApprovalRequest(
        id: ApprovalId('approval-$i'),
        runId: null,
        action: PushCommitsAction(
          repository: address,
          branch: 'task/build-$i',
          commits: const <String>['claude-code: changes from Claude Code'],
        ),
        requestedBy: device.id,
        requestedAt: DateTime.utc(2026, 11, 2),
        decision: null,
      );
      useViewSize(tester, const Size(desktopWidth, desktopHeight));
      await tester.pumpWidget(
        wrapInApp(
          ApprovalDialog(
            request: request,
            runLabel: null,
            askedBy: 'Agent on ${device.name}',
            workflows: const [],
            confirmationMethod: 'Touch ID',
            deviceNames: DeviceNames(galleryDevices),
          ),
        ),
      );

      expect(find.text('hello-counter-$i on ${device.name}'), findsOneWidget);
      expect(find.textContaining('local:'), findsNothing);
    }
  });
}
