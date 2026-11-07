import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/background/start_at_login_choice_store.dart';
import 'package:agent_orchestration/storage.dart';

import '../support/memory_start_at_login_choice_store.dart';
import '../support/random_inputs.dart';
import 'support/logged_computer.dart';
import 'support/switch_contract.dart';

typedef _OtherStateReader = Future<Object?> Function();
typedef _ChoiceStoreMaker = _ChoiceStoreSubject Function(Random random);
typedef _ChoiceStoreCheck = Future<void> Function(
  Random random,
  _ChoiceStoreSubject subject,
);

const int _firstSeed = 9490040;
const int _largestRepeatCount = 4;
const int _largestSaveCount = 6;
const int _largestOtherPreferenceCount = 4;
const String _otherPreferencePrefix = 'other_preference_';
const String _readPrefix =
    'test_start_at_login_choice_store_read_is_start_at_login_chosen_property';
const String _savePrefix =
    'test_start_at_login_choice_store_save_is_start_at_login_chosen_property';
const List<_ChoiceStoreMaker> _storeMakers = <_ChoiceStoreMaker>[
  _makeSharedPreferencesSubject,
  _makeMemorySubject,
  _makeLoggedComputerSubject,
];

final class _ChoiceStoreSubject {
  const _ChoiceStoreSubject({
    required this.implementationName,
    required this.store,
    required this.startingChoice,
    required this.readEverythingElse,
  });

  final String implementationName;
  final StartAtLoginChoiceStore store;
  final bool startingChoice;
  final _OtherStateReader readEverythingElse;
}

_ChoiceStoreSubject _makeSharedPreferencesSubject(Random random) {
  final Map<String, Object> otherPreferences = <String, Object>{};
  final int otherCount = random.nextInt(_largestOtherPreferenceCount);
  for (int i = 0; i < otherCount; i += 1) {
    otherPreferences['$_otherPreferencePrefix$i'] = randomText(random);
  }
  SharedPreferences.setMockInitialValues(otherPreferences);
  return _ChoiceStoreSubject(
    implementationName: 'SharedPreferencesStartAtLoginChoiceStore',
    store: const SharedPreferencesStartAtLoginChoiceStore(),
    startingChoice: true,
    readEverythingElse: () => _readPreferences(otherPreferences.keys),
  );
}

Future<Object?> _readPreferences(Iterable<String> keys) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final Map<String, Object?> values = <String, Object?>{};
  for (final String key in keys) {
    values[key] = preferences.get(key);
  }
  return values;
}

_ChoiceStoreSubject _makeMemorySubject(Random random) {
  final bool startingChoice = random.nextBool();
  return _ChoiceStoreSubject(
    implementationName: 'MemoryStartAtLoginChoiceStore',
    store: MemoryStartAtLoginChoiceStore(isStartAtLoginChosen: startingChoice),
    startingChoice: startingChoice,
    readEverythingElse: _readNothingElse,
  );
}

Future<Object?> _readNothingElse() async => null;

_ChoiceStoreSubject _makeLoggedComputerSubject(Random random) {
  final bool startingChoice = random.nextBool();
  final LoggedComputer computer = LoggedComputer(
    isStartAtLoginChosen: startingChoice,
  );
  computer.isRegistered = random.nextBool();
  computer.isInTray = random.nextBool();
  return _ChoiceStoreSubject(
    implementationName: 'LoggedComputer',
    store: computer,
    startingChoice: startingChoice,
    readEverythingElse: () async => (computer.isRegistered, computer.isInTray),
  );
}

Future<bool> _saveRandomChoices(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  bool lastChoice = subject.startingChoice;
  final int saveCount = random.nextInt(_largestSaveCount);
  for (int i = 0; i < saveCount; i += 1) {
    lastChoice = random.nextBool();
    await subject.store.saveIsStartAtLoginChosen(isChosen: lastChoice);
  }
  return lastChoice;
}

void _testEveryStore({
  required String description,
  required int seed,
  required _ChoiceStoreCheck check,
}) {
  test(description, () async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < contractIterations; i += 1) {
      for (final _ChoiceStoreMaker makeSubject in _storeMakers) {
        await check(random, makeSubject(random));
      }
    }
  });
}

Future<void> _checkStartingChoice(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final bool readChoice = await subject.store.readIsStartAtLoginChosen();

  expect(
    readChoice,
    subject.startingChoice,
    reason: subject.implementationName,
  );
}

Future<void> _checkLastSavedChoiceIsRead(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final bool lastChoice = await _saveRandomChoices(random, subject);

  expect(await subject.store.readIsStartAtLoginChosen(), lastChoice);
}

Future<void> _checkReadingChangesNothing(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final bool lastChoice = await _saveRandomChoices(random, subject);
  final Object? otherStateBefore = await subject.readEverythingElse();
  final int readCount = 1 + random.nextInt(_largestRepeatCount);
  for (int i = 0; i < readCount; i += 1) {
    expect(await subject.store.readIsStartAtLoginChosen(), lastChoice);
  }

  expect(await subject.readEverythingElse(), otherStateBefore);
}

Future<void> _checkSaveRoundTrips(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final bool isChosen = random.nextBool();
  await subject.store.saveIsStartAtLoginChosen(isChosen: isChosen);

  expect(await subject.store.readIsStartAtLoginChosen(), isChosen);
}

Future<void> _checkRepeatedSavesAreSafe(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final bool isChosen = random.nextBool();
  final int saveCount = 1 + random.nextInt(_largestRepeatCount);
  for (int i = 0; i < saveCount; i += 1) {
    await subject.store.saveIsStartAtLoginChosen(isChosen: isChosen);
    expect(await subject.store.readIsStartAtLoginChosen(), isChosen);
  }

  await subject.store.saveIsStartAtLoginChosen(isChosen: !isChosen);
  expect(await subject.store.readIsStartAtLoginChosen(), !isChosen);
}

Future<void> _checkSavingLeavesEverythingElse(
  Random random,
  _ChoiceStoreSubject subject,
) async {
  final Object? otherStateBefore = await subject.readEverythingElse();
  await _saveRandomChoices(random, subject);
  await subject.store.saveIsStartAtLoginChosen(isChosen: random.nextBool());

  expect(
    await subject.readEverythingElse(),
    otherStateBefore,
    reason: subject.implementationName,
  );
}

void main() {
  _testEveryStore(
    description: '${_readPrefix}_fresh_store_reads_its_starting_choice',
    seed: _firstSeed,
    check: _checkStartingChoice,
  );
  _testEveryStore(
    description: '${_readPrefix}_returns_the_last_saved_choice',
    seed: _firstSeed + 1,
    check: _checkLastSavedChoiceIsRead,
  );
  _testEveryStore(
    description: '${_readPrefix}_reading_changes_nothing',
    seed: _firstSeed + 2,
    check: _checkReadingChangesNothing,
  );
  _testEveryStore(
    description: '${_savePrefix}_round_trips',
    seed: _firstSeed + 3,
    check: _checkSaveRoundTrips,
  );
  _testEveryStore(
    description: '${_savePrefix}_repeated_saves_are_safe',
    seed: _firstSeed + 4,
    check: _checkRepeatedSavesAreSafe,
  );
  _testEveryStore(
    description: '${_savePrefix}_leaves_everything_else_alone',
    seed: _firstSeed + 5,
    check: _checkSavingLeavesEverythingElse,
  );
}
