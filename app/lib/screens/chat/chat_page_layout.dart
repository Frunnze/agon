import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const String _noSessionYet = 'Not started yet';

class ChatPageLayout extends StatelessWidget {
  const ChatPageLayout({
    required this.runContext,
    required this.conversation,
    required this.runner,
    required this.thisDevice,
    required this.onBack,
    required this.onSend,
    super.key,
  });

  final ChatRunContext runContext;
  final Conversation conversation;
  final Runner? runner;
  final Device thisDevice;
  final VoidCallback onBack;
  final Future<void> Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    final LayoutSize layoutSize = LayoutSize.of(context);
    final Widget chat = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ConversationView(
            conversation: conversation,
            runnerName: runContext.runnerName,
          ),
        ),
        ChatComposer(onSend: onSend),
      ],
    );

    return Padding(
      padding: pagePaddingFor(layoutSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...spaceVertically(<Widget>[
            PageHeader(
              title: runContext.agentTitle,
              summary: <TextSegment>[TextSegment(runContext.agentSummary)],
              backLink: BackLink(
                label: runContext.runLabel,
                onPressed: onBack,
              ),
            ),
            if (runContext.currentStep.runner != thisDevice.id)
              buildRunnerLinkRoute(
                startName: thisDevice.name,
                endName: runContext.runnerName,
                link: conversation.link,
              ),
          ], pageGapFor(layoutSize)),
          SizedBox(height: pageGapFor(layoutSize)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: chat),
                if (layoutSize.isLarge)
                  const SizedBox(width: AppSpacing.space6),
                if (layoutSize.isLarge)
                  ChatContextPanel(facts: _buildFacts(), onOpenRun: onBack),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Fact> _buildFacts() {
    final String? session = runContext.run.agentSession;
    final Runner? stepRunner = runner;

    return <Fact>[
      Fact(
        term: 'Task',
        description: <TextSegment>[
          TextSegment(
            '${runContext.task.title} · ${runContext.currentStep.name}',
          ),
        ],
      ),
      Fact(
        term: 'Session',
        description: <TextSegment>[
          if (session == null)
            const TextSegment(_noSessionYet)
          else
            TextSegment.monospace(shortenIdentifier(session)),
        ],
      ),
      if (stepRunner != null)
        ...buildRunnerFacts(
          runner: stepRunner,
          place: runContext.task.agentPlace,
        ),
    ];
  }
}
