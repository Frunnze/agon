import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

enum RevokeChoice { keep, revoke }

class RevokeDeviceDialog extends StatelessWidget {
  const RevokeDeviceDialog({
    required this.device,
    required this.workspaceNames,
    required this.lastSeen,
    required this.pairing,
    required this.confirmationMethod,
    super.key,
  });

  final Device device;
  final String workspaceNames;
  final String lastSeen;
  final String pairing;
  final String confirmationMethod;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);

    return AppDialog(
      title: 'Revoke ${device.name}?',
      content: <Widget>[
        const Text(
          'Its key stops working in every workspace at once. To come back, '
          'it has to be paired again.',
        ),
        FactList(
          facts: <Fact>[
            Fact(
              term: 'Role',
              description: <TextSegment>[TextSegment(device.role.label)],
            ),
            Fact(
              term: 'Used in',
              description: <TextSegment>[TextSegment(workspaceNames)],
            ),
            Fact(
              term: 'Last seen',
              description: <TextSegment>[TextSegment(lastSeen)],
            ),
            Fact(
              term: 'Paired',
              description: <TextSegment>[TextSegment(pairing)],
            ),
          ],
        ),
        const DialogNote(
          "Revoking needs your passkey, so a stolen device can't remove "
          'your other devices.',
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Keep device',
          onPressed: () => navigator.pop(RevokeChoice.keep),
        ),
        AppButton.danger(
          label: 'Revoke with $confirmationMethod',
          icon: AppIconKind.fingerprint,
          onPressed: () => navigator.pop(RevokeChoice.revoke),
        ),
      ],
    );
  }
}
