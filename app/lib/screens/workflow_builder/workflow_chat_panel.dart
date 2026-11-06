import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/change_request_composer.dart';
import 'package:agent_orchestration/screens/workflow_builder/builder_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder/panel_heading.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_change_chat.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String chatPanelTitle = 'Change with an agent';
const String chatRequestExample = 'e.g. add a test step';
const String _agentFieldLabel = 'Agent';
const double _personMessageWidthShare = 0.85;
final TextStyle _authorStyle = AppTextStyles.smallMuted.copyWith(
  fontWeight: FontWeight.w700,
);

String describeChangeInProgress(AgentKind agent) {
  return '${agent.label} is changing the workflow…';
}

class WorkflowChatPanel extends StatelessWidget {
  const WorkflowChatPanel({
    required this.chat,
    required this.onClosed,
    super.key,
  });

  final WorkflowChangeChat chat;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: chat, builder: _buildPanel);
  }

  Widget _buildPanel(BuildContext context, Widget? _) {
    final List<Widget> messageViews = <Widget>[
      for (final WorkflowChatMessage message in chat.messages)
        _buildMessage(message),
    ];
    final Widget bottom = chat.isWorking
        ? ChangeInProgressLine(agent: chat.agent)
        : ChangeRequestComposer(
            example: chatRequestExample,
            onSend: (String request) => unawaited(chat.send(request)),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        PanelHeading(title: chatPanelTitle, onDone: onClosed),
        FormFieldBlock(
          label: _agentFieldLabel,
          children: <Widget>[
            SelectField<AgentKindChoice>(
              value: AgentKindChoice(chat.agent),
              entries: buildAgentKindEntries(chat.agent),
              onChanged: _chooseAgent,
            ),
          ],
        ),
        ...messageViews,
        bottom,
      ], AppSpacing.space4),
    );
  }

  Widget _buildMessage(WorkflowChatMessage message) {
    switch (message) {
      case PersonMessage():
        return PersonMessageBubble(text: message.text);
      case AgentMessage(:final AgentKind agent):
        return AgentReply(agent: agent, text: message.text);
    }
  }

  void _chooseAgent(AgentKindChoice choice) {
    final AgentKind? chosenAgent = choice.kind;
    if (chosenAgent == null) {
      throw StateError('The agent list offers no empty choice');
    }
    chat.chooseAgent(chosenAgent);
  }
}

class PersonMessageBubble extends StatelessWidget {
  const PersonMessageBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildBubble);
  }

  Widget _buildBubble(BuildContext context, BoxConstraints limits) {
    final double widestBubble = limits.maxWidth * _personMessageWidthShare;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widestBubble),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: AppColors.actionTint,
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          child: Text(text, style: AppTextStyles.body),
        ),
      ),
    );
  }
}

class AgentReply extends StatelessWidget {
  const AgentReply({required this.agent, required this.text, super.key});

  final AgentKind agent;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(agent.label, style: _authorStyle),
        const SizedBox(height: AppSpacing.space1),
        Text(text, style: AppTextStyles.body),
      ],
    );
  }
}

class ChangeInProgressLine extends StatelessWidget {
  const ChangeInProgressLine({required this.agent, super.key});

  final AgentKind agent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const AppIcon(
          AppIconKind.draft,
          size: AppIconSize.small,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text(
            describeChangeInProgress(agent),
            style: AppTextStyles.smallMuted,
          ),
        ),
      ],
    );
  }
}
