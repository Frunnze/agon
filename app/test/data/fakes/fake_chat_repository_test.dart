import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/task_repositories.dart';

void main() {
  test('test_find_conversation_property_unknown_runs_are_not_found', () {
    final Random random = seededRandom(301);
    final FakeChatRepository repository = FakeChatRepository(
      conversations: <Conversation>[galleryConversationAwaitingApproval],
      taskRepository: buildGalleryTaskRepository(),
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = RunId('missing-${randomText(random)}');

      expect(
        () => repository.findConversation(runId),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        repository.findConversation(GalleryRunIds.release42).runId,
        GalleryRunIds.release42,
      );
    }
  });

  test('test_send_message_property_queues_only_when_link_is_lost', () async {
    final Random random = seededRandom(302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Conversation seed = pickOne(random, <Conversation>[
        galleryConversationAwaitingApproval,
        galleryConversationReconnecting,
      ]);
      final FakeChatRepository repository = FakeChatRepository(
        conversations: <Conversation>[seed],
        taskRepository: buildGalleryTaskRepository(),
        clock: FixedClock(galleryNow),
      );
      final String text = randomText(random);

      if (text.trim().isEmpty) {
        await expectLater(
          repository.sendMessage(seed.runId, text),
          throwsA(isA<ArgumentError>()),
        );
      } else {
        final ChatMessage sent = await repository.sendMessage(
          seed.runId,
          text,
        );
        final Conversation after = repository.findConversation(seed.runId);

        expect(sent.text, text.trim());
        expect(sent.author, ChatAuthor.you);
        expect(sent.waitingToSend, seed.link == RunnerLink.unreachable);
        expect(after.messages.length, seed.messages.length + 1);
      }
    }
  });
}
