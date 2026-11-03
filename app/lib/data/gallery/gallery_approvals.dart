import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/approval.dart';

final List<ApprovalRequest> galleryApprovals =
    List<ApprovalRequest>.unmodifiable(<ApprovalRequest>[
      ApprovalRequest(
        id: GalleryApprovalIds.pushRelease,
        runId: GalleryRunIds.release42,
        action: PushCommitsAction(
          repository: 'github.com/acme/app',
          branch: 'release',
          commits: const <String>[
            'a41f2c0 Use CI signing profile',
            '9be07d1 Bump build number to 214',
            '3c5e8aa Update release notes',
          ],
        ),
        requestedBy: GalleryDeviceIds.macStudio,
        requestedAt: galleryToday(14, 9, 20),
        decision: null,
      ),
      ApprovalRequest(
        id: GalleryApprovalIds.signTrainRanker,
        runId: null,
        action: const SignWorkflowAction(
          workflowId: GalleryWorkflowIds.trainRanker,
        ),
        requestedBy: GalleryDeviceIds.airLaptop,
        requestedAt: galleryToday(13, 9),
        decision: null,
      ),
    ]);

final ApprovalRequest galleryDeniedPushApproval = ApprovalRequest(
  id: GalleryApprovalIds.pushBillingRename,
  runId: GalleryRunIds.renameBillingModule1,
  action: PushCommitsAction(
    repository: 'github.com/acme/app',
    branch: galleryKeptBranch,
    commits: const <String>['5d21e9b Rename the billing module'],
  ),
  requestedBy: GalleryDeviceIds.officeServer,
  requestedAt: galleryTwoDaysAgo(14, 22, 5),
  decision: SignedDecision(
    decision: ApprovalDecision.denied,
    decidedBy: GalleryDeviceIds.airLaptop,
    decidedAt: galleryTwoDaysAgo(14, 25, 2),
    signature: const <int>[0],
  ),
);

final ApprovalRequest galleryRunCommandApproval = ApprovalRequest(
  id: GalleryApprovalIds.runReleaseTests,
  runId: GalleryRunIds.release42,
  action: const RunCommandAction(
    tool: 'Bash',
    command: 'xcodebuild test -scheme App',
  ),
  requestedBy: GalleryDeviceIds.macStudio,
  requestedAt: galleryToday(14, 9, 20),
  decision: null,
);
