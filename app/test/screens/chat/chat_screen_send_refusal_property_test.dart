import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const String _sendLabel = 'Send';
const String _typedMessage = 'Tag the build too.';

RefusedActionCase _buildSendMessageCase() {
  late ChatRepository chatRepository;

  return RefusedActionCase(
    functionName: 'send_message',
    actionLabel: _sendLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies base = buildDependenciesWithConversation(
        galleryConversationReconnecting,
      );
      chatRepository = RefusingChatRepository(
        stored: base.chatRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: _chatRoute,
        dependencies: replaceRepositories(
          base,
          chatRepository: chatRepository,
        ),
      );
    },
    performAction: (tester) async {
      final Finder field = find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, _typedMessage);
      await tester.pump();
      await tapButtonLabelled(tester, _sendLabel);
    },
    expectSucceeded: (tester) {
      final Conversation conversation = chatRepository.findConversation(
        GalleryRunIds.release42,
      );
      expect(conversation.messages.last.text, _typedMessage);
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildSendMessageCase(), seed: 91501);
}
