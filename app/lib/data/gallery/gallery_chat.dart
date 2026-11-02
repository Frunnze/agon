import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

const String _askingForApproval =
    "The build passes now. Pushing needs your approval, so I'm asking "
    'for it';
const String _finishedSentence = '.';

ChatMessage _toolStep(DateTime at, String text) {
  return ChatMessage(
    at: at,
    author: ChatAuthor.tool,
    text: text,
    isError: false,
    waitingToSend: false,
  );
}

ChatMessage _message(DateTime at, ChatAuthor author, String text) {
  return ChatMessage(
    at: at,
    author: author,
    text: text,
    isError: false,
    waitingToSend: false,
  );
}

List<ChatMessage> _buildBuildFixMessages(String lastAgentText) {
  return <ChatMessage>[
    _toolStep(
      galleryToday(14, 6),
      'Ran xcodebuild -scheme App -configuration Release',
    ),
    ChatMessage(
      at: galleryToday(14, 6, 30),
      author: ChatAuthor.tool,
      text: 'Build failed: no Apple Distribution certificate',
      isError: true,
      waitingToSend: false,
    ),
    _message(
      galleryToday(14, 6, 40),
      ChatAuthor.agent,
      'The release build uses automatic signing, but this runner has no '
      'Apple Distribution certificate. I can switch the release settings '
      'to the CI signing profile from the vault.',
    ),
    _message(
      galleryToday(14, 7),
      ChatAuthor.you,
      'Do that, then push to the release branch.',
    ),
    _toolStep(
      galleryToday(14, 7, 10),
      'Edited ios/App.xcodeproj/project.pbxproj',
    ),
    _toolStep(
      galleryToday(14, 7, 15),
      'Ran xcodebuild -scheme App -configuration Release',
    ),
    _toolStep(galleryToday(14, 8, 50), 'Build succeeded in 3 min 41 s'),
    _message(galleryToday(14, 9), ChatAuthor.agent, lastAgentText),
  ];
}

final List<ChatMessage> galleryRunChat = List<ChatMessage>.unmodifiable(
  _buildBuildFixMessages('$_askingForApproval$_finishedSentence'),
);

final Conversation galleryConversationAwaitingApproval = Conversation(
  runId: GalleryRunIds.release42,
  messages: galleryRunChat,
  link: RunnerLink.direct,
  linkLostAt: null,
  agentActivity: AgentActivity.idle,
);

final Conversation galleryConversationReplying = Conversation(
  runId: GalleryRunIds.release42,
  messages: _buildBuildFixMessages(_askingForApproval),
  link: RunnerLink.direct,
  linkLostAt: null,
  agentActivity: AgentActivity.replying,
);

final Conversation galleryConversationReconnecting = Conversation(
  runId: GalleryRunIds.release42,
  messages: <ChatMessage>[
    ...galleryRunChat,
    ChatMessage(
      at: galleryToday(14, 9, 30),
      author: ChatAuthor.you,
      text: 'Also bump the build number to 215.',
      isError: false,
      waitingToSend: true,
    ),
  ],
  link: RunnerLink.unreachable,
  linkLostAt: galleryToday(14, 9, 5),
  agentActivity: AgentActivity.idle,
);
