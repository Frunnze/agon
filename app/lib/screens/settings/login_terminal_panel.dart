import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _enterKey = '\r';

class LoginTerminalPanel extends StatefulWidget {
  const LoginTerminalPanel({
    required this.terminal,
    required this.onType,
    required this.onClose,
    super.key,
  });

  final LoginTerminal terminal;
  final Future<void> Function(String keys) onType;
  final VoidCallback onClose;

  @override
  State<LoginTerminalPanel> createState() => _LoginTerminalPanelState();
}

class _LoginTerminalPanelState extends State<LoginTerminalPanel> {
  final TextEditingController _keysController = TextEditingController();

  @override
  void dispose() {
    _keysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRunning = widget.terminal.state == LoginTerminalState.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        _buildScreen(isRunning),
        if (isRunning) _buildKeysRow(),
        if (isRunning)
          const Text(terminalHint, style: AppTextStyles.smallMuted),
        Wrap(
          children: <Widget>[
            AppButton.secondary(label: closeLabel, onPressed: widget.onClose),
          ],
        ),
      ], AppSpacing.space3),
    );
  }

  Widget _buildScreen(bool isRunning) {
    final List<String> lines = widget.terminal.lines;
    final String? problem = widget.terminal.problem;
    final List<Widget> shownLines = <Widget>[
      _TerminalLine(
        prompt: commandPrompt,
        text: widget.terminal.command,
        color: AppColors.ink,
        showsCursor: isRunning && lines.isEmpty,
      ),
      for (int index = 0; index < lines.length; index += 1)
        _TerminalLine(
          prompt: null,
          text: lines[index],
          color: AppColors.ink,
          showsCursor: isRunning && index == lines.length - 1,
        ),
      if (problem != null)
        _TerminalLine(
          prompt: null,
          text: problem,
          color: AppColors.danger,
          showsCursor: false,
        ),
    ];

    return Semantics(
      label: terminalLabel,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: AppSizes.logMaximumHeight,
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: SelectionArea(child: CodePanel(lines: shownLines)),
        ),
      ),
    );
  }

  Widget _buildKeysRow() {
    final LayoutDensity layoutDensity = LayoutDensity.of(context);
    final double controlHeight = AppSizes.controlHeightFor(layoutDensity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _keysController,
            autocorrect: false,
            enableSuggestions: false,
            style: AppTextStyles.body.merge(AppTextStyles.monospace),
            onSubmitted: (String _) => unawaited(_sendKeys()),
            decoration: const InputDecoration(
              hintText: terminalPlaceholder,
              semanticCounterText: terminalLabel,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        SizedBox(
          height: controlHeight,
          child: AppButton.secondary(
            label: sendLabel,
            icon: AppIconKind.send,
            onPressed: () => unawaited(_sendKeys()),
          ),
        ),
      ],
    );
  }

  Future<void> _sendKeys() async {
    final String keys = '${_keysController.text}$_enterKey';
    _keysController.clear();
    await widget.onType(keys);
  }
}

class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.prompt,
    required this.text,
    required this.color,
    required this.showsCursor,
  });

  final String? prompt;
  final String text;
  final Color color;
  final bool showsCursor;

  @override
  Widget build(BuildContext context) {
    final String? shownPrompt = prompt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: color),
          children: <InlineSpan>[
            if (shownPrompt != null)
              TextSpan(
                text: shownPrompt,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            if (shownPrompt != null)
              const WidgetSpan(child: SizedBox(width: AppSpacing.space2)),
            TextSpan(text: text),
            if (showsCursor) const WidgetSpan(child: BlinkingCursor()),
          ],
        ),
      ),
    );
  }
}
