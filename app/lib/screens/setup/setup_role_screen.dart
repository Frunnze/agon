import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/setup_panel.dart';

ChoiceOption<DeviceRole> describeSetupRoleChoice({
  required DeviceRole role,
  required String deviceKind,
}) {
  switch (role) {
    case DeviceRole.clientAndRunner:
      return ChoiceOption<DeviceRole>(
        value: role,
        title: 'Client and runner',
        detail: 'Use the app here and run tasks on this $deviceKind too.',
      );
    case DeviceRole.client:
      return ChoiceOption<DeviceRole>(
        value: role,
        title: 'Client only',
        detail: 'Start workflows, chat with agents and approve what they do.',
      );
    case DeviceRole.runner:
      return ChoiceOption<DeviceRole>(
        value: role,
        title: 'Runner only',
        detail: 'Run tasks for your other devices, each in its own sandbox.',
      );
  }
}

class SetupRoleScreen extends StatefulWidget {
  const SetupRoleScreen({
    required this.deviceKind,
    required this.roles,
    required this.navigation,
    super.key,
  });

  final String deviceKind;
  final List<DeviceRole> roles;
  final AppNavigation navigation;

  @override
  State<SetupRoleScreen> createState() => _SetupRoleScreenState();
}

class _SetupRoleScreenState extends State<SetupRoleScreen> {
  late DeviceRole _role = widget.roles.first;

  @override
  Widget build(BuildContext context) {
    final String deviceKind = widget.deviceKind;
    final List<ChoiceOption<DeviceRole>> choices = <ChoiceOption<DeviceRole>>[
      for (final DeviceRole role in widget.roles)
        describeSetupRoleChoice(role: role, deviceKind: deviceKind),
    ];

    return SetupPanel(
      step: 'Step 1 of 2',
      title: 'How will this $deviceKind be used?',
      children: <Widget>[
        Semantics(
          label: 'Device role',
          container: true,
          child: ChoiceListField<DeviceRole>(
            options: choices,
            selected: _role,
            onChanged: (DeviceRole role) => setState(() => _role = role),
          ),
        ),
        Text(
          "The role is part of this $deviceKind's pairing. Later, only a "
          'device you already trust can change it.',
          style: AppTextStyles.bodyMuted,
        ),
        SetupActions(
          children: <Widget>[
            AppButton.primary(
              label: 'Continue',
              onPressed: () =>
                  widget.navigation.openRoute(PairingCodeEntryRoute(_role)),
            ),
          ],
        ),
      ],
    );
  }
}
