import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/apply_layout_density.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';

const String retryStartupLabel = 'Try again';
const String setUpDeviceAgainLabel = 'Set up this device again';
const String _startingText = 'Starting this device…';
const String _problemTitle = 'This device could not start';

class StartupWaitingPage extends StatelessWidget {
  const StartupWaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: applyLayoutDensity,
      home: const Scaffold(body: Center(child: Text(_startingText))),
    );
  }
}

class StartupProblemPage extends StatelessWidget {
  const StartupProblemPage({
    required this.problem,
    required this.onRetry,
    required this.onSetUpAgain,
    super.key,
  });

  final String problem;
  final VoidCallback onRetry;
  final VoidCallback? onSetUpAgain;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: applyLayoutDensity,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: EmptyState(
            title: _problemTitle,
            message: problem,
            action: Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: _buildActions(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    final List<Widget> actions = <Widget>[
      AppButton.primary(label: retryStartupLabel, onPressed: onRetry),
    ];
    final VoidCallback? setUpAgain = onSetUpAgain;
    if (setUpAgain != null) {
      actions.add(
        AppButton.secondary(
          label: setUpDeviceAgainLabel,
          onPressed: setUpAgain,
        ),
      );
    }
    return actions;
  }
}
