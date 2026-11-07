import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'support/chat_repository_rig.dart';

const int _largestNotificationCount = 8;

final class _HeardChanges {
  int count = 0;

  void hear() => count += 1;
}

void main() {
  test('test_add_listener_property_hears_every_run_source_change', () {
    final Random random = seededRandom(76606);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final int changeCount = random.nextInt(_largestNotificationCount);
      int heard = 0;
      fixture.chat.addListener(() => heard += 1);

      for (int change = 0; change < changeCount; change += 1) {
        fixture.runSource.storeRun(randomMappedRun(random));
      }

      expect(heard, changeCount);
    }
  });

  test('test_add_listener_property_every_listener_hears_each_change', () {
    final Random random = seededRandom(76607);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final List<int> heard = List<int>.filled(1 + random.nextInt(4), 0);
      for (int listener = 0; listener < heard.length; listener += 1) {
        fixture.chat.addListener(() => heard[listener] += 1);
      }

      fixture.runSource.storeRun(randomMappedRun(random));

      expect(heard, everyElement(1));
    }
  });

  test('test_add_listener_property_hears_nothing_before_a_change', () {
    final Random random = seededRandom(76608);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      int heard = 0;
      fixture.chat.addListener(() => heard += 1);

      fixture.chat.findConversation(fixture.runSource.runs.keys.first);

      expect(heard, 0);
      expect(fixture.node.commands, isEmpty);
    }
  });

  test('test_remove_listener_property_removed_listener_hears_nothing', () {
    final Random random = seededRandom(76609);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final _HeardChanges removed = _HeardChanges();
      fixture.chat.addListener(removed.hear);
      fixture.chat.removeListener(removed.hear);

      fixture.runSource.storeRun(randomMappedRun(random));

      expect(removed.count, 0);
    }
  });

  test('test_remove_listener_property_other_listeners_keep_hearing', () {
    final Random random = seededRandom(76610);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      final _HeardChanges removed = _HeardChanges();
      final _HeardChanges kept = _HeardChanges();
      fixture.chat.addListener(removed.hear);
      fixture.chat.addListener(kept.hear);
      fixture.chat.removeListener(removed.hear);

      fixture.runSource.storeRun(randomMappedRun(random));

      expect(removed.count, 0);
      expect(kept.count, 1);
    }
  });

  test('test_remove_listener_property_unknown_listener_is_harmless', () {
    final Random random = seededRandom(76611);
    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatRig fixture = buildChatRig(random);
      int heard = 0;
      fixture.chat.addListener(() => heard += 1);

      fixture.chat.removeListener(() {});
      fixture.runSource.storeRun(randomMappedRun(random));

      expect(heard, 1);
    }
  });
}
