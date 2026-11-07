import 'dart:math';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/random_run_records.dart';

List<ChatMessage> _randomMessages(Random random) {
  return randomRecordsOf(random, randomChatMessage);
}

ModelFieldValues _randomConversationFields(Random random) {
  return <Object?>[
    randomRunId(random),
    _randomMessages(random),
    pickOne(random, RunnerLink.values),
    if (random.nextBool()) null else randomPreciseMoment(random),
    pickOne(random, AgentActivity.values),
  ];
}

Conversation _buildConversation(ModelFieldValues fieldValues) {
  return Conversation(
    runId: fieldValues[0]! as RunId,
    messages: fieldValues[1]! as List<ChatMessage>,
    link: fieldValues[2]! as RunnerLink,
    linkLostAt: fieldValues[3] as DateTime?,
    agentActivity: fieldValues[4]! as AgentActivity,
  );
}

ModelFieldValues _readFieldsBesidesMessages(Conversation conversation) {
  return <Object?>[
    conversation.runId,
    conversation.link,
    conversation.linkLostAt,
    conversation.agentActivity,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<Conversation>(
      testNamePrefix: 'test_conversation_constructor_property',
      seed: 690501,
      randomFieldValues: _randomConversationFields,
      construct: _buildConversation,
      readFieldValues: (Conversation conversation) => <Object?>[
        conversation.runId,
        conversation.messages,
        conversation.link,
        conversation.linkLostAt,
        conversation.agentActivity,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<Conversation, ChatMessage>(
      testNamePrefix: 'test_conversation_constructor_property_messages',
      seed: 690511,
      buildElement: randomChatMessage,
      construct: (Random random, List<ChatMessage> messages) => Conversation(
        runId: randomRunId(random),
        messages: messages,
        link: pickOne(random, RunnerLink.values),
        linkLostAt: null,
        agentActivity: pickOne(random, AgentActivity.values),
      ),
      readList: (Conversation conversation) => conversation.messages,
    ),
  );

  testModelCopyProperties(
    ModelCopy<Conversation, List<ChatMessage>>(
      testNamePrefix: 'test_with_messages_property',
      seed: 690521,
      randomModel: (Random random) =>
          _buildConversation(_randomConversationFields(random)),
      randomChange: _randomMessages,
      applyChange: (
        Conversation conversation,
        List<ChatMessage> nextMessages,
      ) => conversation.withMessages(nextMessages),
      readChangedField: (Conversation conversation) => conversation.messages,
      readOtherFields: _readFieldsBesidesMessages,
    ),
  );

  testListCopyProperties(
    ListCopy<Conversation, ChatMessage>(
      testNamePrefix: 'test_with_messages_property_messages',
      seed: 690531,
      buildElement: randomChatMessage,
      construct: (Random random, List<ChatMessage> messages) =>
          _buildConversation(_randomConversationFields(random))
              .withMessages(messages),
      readList: (Conversation conversation) => conversation.messages,
    ),
  );
}
