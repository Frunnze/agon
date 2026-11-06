import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

const double _userMessageWidthShare = 0.85;
const String _editedPrefix = 'Edited';
const String _ranPrefix = 'Ran';

AppIconKind chooseToolStepIcon(ChatMessage message) {
  if (message.isError) {
    return AppIconKind.alert;
  }
  if (message.text.startsWith(_editedPrefix)) {
    return AppIconKind.edit;
  }
  if (message.text.startsWith(_ranPrefix)) {
    return AppIconKind.terminal;
  }
  return AppIconKind.check;
}

class ToolStepView extends StatelessWidget {
  const ToolStepView({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final Color color = message.isError
        ? AppColors.danger
        : AppColors.inkMuted;

    return Row(
      children: <Widget>[
        AppIcon(
          chooseToolStepIcon(message),
          size: AppIconSize.small,
          color: color,
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text(
            message.text,
            style: AppTextStyles.small
                .merge(AppTextStyles.monospace)
                .copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class AgentMessageView extends StatelessWidget {
  const AgentMessageView({
    required this.text,
    required this.cursor,
    super.key,
  });

  final String text;
  final CursorVisibility cursor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Agent',
              style: AppTextStyles.smallMuted.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: text),
                  if (cursor == CursorVisibility.shown)
                    const WidgetSpan(child: BlinkingCursor()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserMessageView extends StatelessWidget {
  const UserMessageView({
    required this.message,
    required this.runnerName,
    required this.availableWidth,
    super.key,
  });

  final ChatMessage message;
  final String runnerName;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final double maximumWidth = min(
      AppSizes.measure,
      availableWidth * _userMessageWidthShare,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maximumWidth),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: AppColors.actionTint,
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message.text),
            if (message.waitingToSend)
              const SizedBox(height: AppSpacing.space1),
            if (message.waitingToSend)
              StatusLabel(
                text: 'Sends when $runnerName is back',
                tone: StatusTone.muted,
                icon: AppIconKind.clock,
              ),
          ],
        ),
      ),
    );
  }
}
