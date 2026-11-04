import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/setup_panel.dart';

String describePairedRoleNote({
  required DeviceRole role,
  required String trayName,
}) {
  if (!roleRunsTasks(role)) {
    return 'Start tasks, chat with agents and approve what they do from '
        'here.';
  }
  return 'It starts when you log in, stays in the $trayName and keeps '
      'running tasks after you close this window. Your other devices '
      'can send it work now.';
}

AppRoute chooseRouteAfterPairing(DeviceRole role) {
  switch (role) {
    case DeviceRole.client:
      return const SectionRoute(AppSection.tasks);
    case DeviceRole.runner:
    case DeviceRole.clientAndRunner:
      return const SectionRoute(AppSection.devices);
  }
}

class PairingDoneScreen extends StatelessWidget {
  const PairingDoneScreen({
    required this.outcome,
    required this.deviceKind,
    required this.trayName,
    required this.navigation,
    super.key,
  });

  final PairingOutcome outcome;
  final String deviceKind;
  final String trayName;
  final AppNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final bool runsTasks = roleRunsTasks(outcome.role);
    final String? approverName = outcome.approverName;

    return SetupPanel(
      step: approverName == null ? 'Account created' : 'Paired',
      title:
          'This $deviceKind is now ${describeRoleWithArticle(outcome.role)}',
      children: <Widget>[
        Text(
          describePairedRoleNote(role: outcome.role, trayName: trayName),
          style: AppTextStyles.bodyMuted,
        ),
        FactList(
          facts: <Fact>[
            Fact(
              term: 'Used in',
              description: <TextSegment>[
                TextSegment(outcome.workspaceNames.join(', ')),
              ],
            ),
            Fact(
              term: 'Name',
              description: <TextSegment>[
                TextSegment.monospace(outcome.deviceName),
              ],
            ),
            if (runsTasks && outcome.runnerLabels.isNotEmpty)
              Fact.chips(term: 'Labels', chips: outcome.runnerLabels),
            if (approverName != null)
              Fact(
                term: 'Approved by',
                description: <TextSegment>[
                  TextSegment.monospace(approverName),
                ],
              ),
          ],
        ),
        SetupActions(
          children: <Widget>[
            AppButton.primary(
              label: 'Done',
              onPressed: () => navigation.openSection(
                chooseRouteAfterPairing(outcome.role),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
