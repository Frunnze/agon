import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';

const SectionRoute _workflowsRoute = SectionRoute(AppSection.workflows);

class WorkflowChangeScreen extends StatelessWidget {
  const WorkflowChangeScreen({
    required this.workflowId,
    required this.workflowRepository,
    required this.deviceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final WorkflowId workflowId;
  final WorkflowRepository workflowRepository;
  final DeviceRepository deviceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: workflowRepository,
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    final Workflow workflow = workflowRepository.findWorkflow(workflowId);
    final WorkflowChange? change = workflowRepository.findPendingChange(
      workflowId,
    );
    final BackLink backLink = BackLink(
      label: 'Workflows',
      onPressed: () => navigation.returnTo(_workflowsRoute),
    );

    if (change == null) {
      return AppPage(
        children: <Widget>[
          PageHeader(title: workflow.name, backLink: backLink),
          const MutedNote('There is no change waiting to be signed.'),
        ],
      );
    }

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: workflow.name,
          summary: <TextSegment>[
            TextSegment(
              describeChangeSummary(
                change: change,
                deviceNames: DeviceNames(deviceRepository.listDevices()),
                now: clock.now(),
              ),
            ),
          ],
          backLink: backLink,
          actions: <Widget>[
            AppButton.secondary(
              label: 'Discard change',
              onPressed: _discardChange,
            ),
            AppButton.primary(label: 'Sign change', onPressed: _signChange),
          ],
        ),
        NoticeBanner(
          tone: BannerTone.attention,
          icon: AppIconKind.alert,
          title: "This version won't run until you sign it",
          body: <Widget>[
            Text(describeKeptVersion(workflow.signature, clock.now())),
          ],
        ),
        SplitLayout(
          start: PageSection(
            title: 'What changes',
            children: <Widget>[
              FactList(
                facts: <Fact>[
                  for (final WorkflowDifference difference
                      in change.differences)
                    Fact(
                      term: difference.subject,
                      description: <TextSegment>[
                        TextSegment(difference.change),
                      ],
                    ),
                ],
              ),
            ],
          ),
          end: PageSection(
            title: 'Changes',
            children: <Widget>[
              CodeBlock(
                lines: diffDocumentLines(
                  change.signedDocument,
                  change.changedDocument,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _discardChange() async {
    await workflowRepository.discardChange(workflowId);
    navigation.returnTo(_workflowsRoute);
  }

  Future<void> _signChange() async {
    await workflowRepository.signWorkflow(workflowId);
    navigation.returnTo(_workflowsRoute);
  }
}
