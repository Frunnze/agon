import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

class ConversationView extends StatelessWidget {
  const ConversationView({
    required this.conversation,
    required this.runnerName,
    super.key,
  });

  final Conversation conversation;
  final String runnerName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildItems);
  }

  Widget _buildItems(BuildContext context, BoxConstraints limits) {
    final List<Widget> items = <Widget>[
      for (final ChatMessage message in conversation.messages)
        _buildMessage(message, limits.maxWidth),
    ];
    final DateTime? linkLostAt = conversation.linkLostAt;
    if (linkLostAt != null) {
      items.insert(
        _findFirstMessageAfter(linkLostAt),
        _buildLostLinkBanner(linkLostAt),
      );
    }

    if (_isWorkingBeforeItsNextWords()) {
      items.add(_buildWorkingAgentLine());
    }

    if (items.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          title: 'No messages yet',
          message:
              "The agent's replies and the commands it runs show up here as "
              'it works.',
          action: null,
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ListView.separated(
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.space4),
        itemCount: items.length,
        separatorBuilder: _buildSeparator,
        itemBuilder: (BuildContext _, int index) =>
            items[items.length - 1 - index],
      ),
    );
  }

  int _findFirstMessageAfter(DateTime moment) {
    final List<ChatMessage> messages = conversation.messages;

    for (int index = 0; index < messages.length; index += 1) {
      if (messages[index].at.isAfter(moment)) {
        return index;
      }
    }
    return messages.length;
  }

  Widget _buildSeparator(BuildContext context, int index) {
    return const SizedBox(height: AppSpacing.space4);
  }

  Widget _buildMessage(ChatMessage message, double availableWidth) {
    switch (message.author) {
      case ChatAuthor.tool:
        return ToolStepView(message: message);
      case ChatAuthor.you:
        return UserMessageView(
          message: message,
          runnerName: runnerName,
          availableWidth: availableWidth,
        );
      case ChatAuthor.agent:
        final bool isReplying =
            conversation.agentActivity == AgentActivity.replying &&
            identical(message, conversation.messages.last);
        return AgentMessageView(
          text: message.text,
          cursor: isReplying
              ? CursorVisibility.shown
              : CursorVisibility.hidden,
        );
    }
  }

  bool _isWorkingBeforeItsNextWords() {
    if (conversation.agentActivity != AgentActivity.replying) {
      return false;
    }

    final List<ChatMessage> messages = conversation.messages;
    if (messages.isEmpty) {
      return true;
    }
    return messages.last.author != ChatAuthor.agent;
  }

  Widget _buildWorkingAgentLine() {
    return const AgentMessageView(text: '', cursor: CursorVisibility.shown);
  }

  Widget _buildLostLinkBanner(DateTime linkLostAt) {
    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.alert,
      title: 'Lost the direct link at ${formatClockTime(linkLostAt)}',
      body: const <Widget>[
        Text(
          'Trying the relay now. The agent keeps working in its sandbox, '
          'and your messages wait here until it is back.',
        ),
      ],
    );
  }
}
