import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/code_tracking.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/numbered_list.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const List<String> _newDeviceSteps = <String>[
  'Open the app and choose how the device will be used.',
  'Enter this code, or scan the QR code with a phone.',
  'Come back here, check four words match, then approve.',
];

class PairingCodeScreen extends StatelessWidget {
  const PairingCodeScreen({
    required this.pairingRepository,
    required this.workspaceRepository,
    required this.clock,
    required this.navigation,
    super.key,
  });

  final PairingRepository pairingRepository;
  final WorkspaceRepository workspaceRepository;
  final Clock clock;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        pairingRepository,
        workspaceRepository,
      ]),
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context, Widget? _) {
    return AppPage(
      children: <Widget>[
        PageHeader(
          title: 'Add a device',
          backLink: BackLink(
            label: 'Your devices',
            onPressed: navigation.closeRoute,
          ),
          summary: const <TextSegment>[
            TextSegment(
              'Pair it once, then use it in any of your workspaces.',
            ),
          ],
          actions: <Widget>[
            AppButton.secondary(
              label: 'Cancel',
              onPressed: () => unawaited(_cancelPairing()),
            ),
          ],
        ),
        SplitLayout(
          start: _buildCodeCard(context),
          end: PageSection(
            title: 'On the new device',
            children: <Widget>[
              const NumberedList(entries: _newDeviceSteps),
              _buildRequestState(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelPairing() async {
    if (pairingRepository.findActiveSession() != null) {
      await pairingRepository.cancelPairing();
    }
    navigation.closeRoute();
  }

  Widget _buildCodeCard(BuildContext context) {
    final PairingSession? session = pairingRepository.findActiveSession();
    final String serverAddress = workspaceRepository
        .currentWorkspace()
        .appServerAddress;
    final List<Widget> cardContent = session == null
        ? <Widget>[
            const Text('This code expired.'),
            AppButton.primary(
              label: 'Show a new code',
              onPressed: () => unawaited(pairingRepository.startPairing()),
            ),
          ]
        : <Widget>[
            PairingQrCode(
              invitation: PairingInvitation(
                code: session.code,
                serverAddress: serverAddress,
              ),
            ),
            Semantics(
              label: 'Pairing code ${session.code}',
              excludeSemantics: true,
              child: Text(
                session.code,
                style: AppTextStyles.monospace.copyWith(
                  color: AppColors.ink,
                  fontSize: AppFontSizes.title,
                  fontWeight: FontWeight.w700,
                  letterSpacing: codeLetterSpacingFor(
                    textScaler: MediaQuery.textScalerOf(context),
                    fontSize: AppFontSizes.title,
                  ),
                ),
              ),
            ),
            StatusLabel(
              text: describeTimeLeft(
                expiresAt: session.expiresAt,
                now: clock.now(),
              ),
              tone: StatusTone.muted,
              icon: AppIconKind.clock,
            ),
            MixedText(<TextSegment>[
              const TextSegment('App server '),
              TextSegment.monospace(describeServerHost(serverAddress)),
            ], style: AppTextStyles.smallMuted),
          ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppColors.raised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Column(children: spaceVertically(cardContent, AppSpacing.space3)),
    );
  }

  Widget _buildRequestState() {
    final PairingRequest? request = pairingRepository.findPendingRequest();
    if (request == null) {
      return const StatusLabel(
        text: 'Waiting for the new device',
        tone: StatusTone.normal,
        icon: AppIconKind.spinner,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton.primary(
        label: 'Check ${request.deviceName}',
        onPressed: () => navigation.openRoute(const PairingApprovalRoute()),
      ),
    );
  }
}
