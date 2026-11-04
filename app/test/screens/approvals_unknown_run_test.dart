import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const SectionRoute _approvalsRoute = SectionRoute(AppSection.approvals);
const int _unknownRunCases = 3;
const String _galleryRowTitle = 'Run the tests';

ApprovalRequest _buildApprovalForRun(RunId runId) {
  return ApprovalRequest(
    id: galleryRunCommandApproval.id,
    runId: runId,
    action: galleryRunCommandApproval.action,
    requestedBy: galleryRunCommandApproval.requestedBy,
    requestedAt: galleryRunCommandApproval.requestedAt,
    decision: null,
  );
}

void main() {
  testWidgets(
    'test_approvals_screen_property_unknown_runs_still_list_the_request',
    (WidgetTester tester) async {
      final Random random = seededRandom(7311);

      for (int i = 0; i < _unknownRunCases; i += 1) {
        final int runNumber = random.nextInt(1 << 30);
        final RunId unknownRunId = RunId('unknown-run-$runNumber');

        await pumpApp(
          tester,
          size: desktopSize,
          route: _approvalsRoute,
          dependencies: buildDependenciesWithApprovals(<ApprovalRequest>[
            _buildApprovalForRun(unknownRunId),
          ]),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(_galleryRowTitle), findsOneWidget);
      }
    },
  );
}
