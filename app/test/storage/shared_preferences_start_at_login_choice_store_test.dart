import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/storage.dart';

import '../support/random_inputs.dart';

void main() {
  test(
    'test_read_is_start_at_login_chosen_property_chosen_until_saved_off',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const SharedPreferencesStartAtLoginChoiceStore store =
          SharedPreferencesStartAtLoginChoiceStore();

      expect(await store.readIsStartAtLoginChosen(), isTrue);
    },
  );

  test('test_save_is_start_at_login_chosen_property_round_trips', () async {
    final Random random = seededRandom(10054);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SharedPreferencesStartAtLoginChoiceStore store =
        SharedPreferencesStartAtLoginChoiceStore();

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isChosen = random.nextBool();
      await store.saveIsStartAtLoginChosen(isChosen: isChosen);
      expect(await store.readIsStartAtLoginChosen(), isChosen);
    }
  });
}
