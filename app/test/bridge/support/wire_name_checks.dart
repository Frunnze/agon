import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';

typedef WireNameDecoder<Choice> = Choice Function(Object? json);

const String _zeroWidthSpace = '\u200b';

List<String> nearMissWireNames(
  Random random,
  String wireName,
  String codeName,
) {
  return <String>[
    wireName.toUpperCase(),
    wireName.toLowerCase(),
    ' $wireName',
    '$wireName ',
    '$wireName\n',
    '$wireName$_zeroWidthSpace',
    wireName.replaceAll('_', '-'),
    wireName.replaceAll('_', ' '),
    codeName,
    '$wireName${randomText(random)}?',
    '',
  ];
}

void expectDecodesEveryWireName<Choice extends Enum>(
  List<Choice> choices,
  WireNameDecoder<Choice> decode,
) {
  for (final Choice choice in choices) {
    final String wireName = readWireName(choice);
    final Object? rereadName = jsonDecode(jsonEncode(wireName));

    expect(decode(wireName), same(choice));
    expect(decode(rereadName), same(choice));
  }
}

void expectRejectsNearMissWireNames<Choice extends Enum>(
  Random random,
  List<Choice> choices,
  WireNameDecoder<Choice> decode,
) {
  final Set<String> wireNames = <String>{};
  for (final Choice choice in choices) {
    wireNames.add(readWireName(choice));
  }

  final Choice choice = pickOne(random, choices);
  final String wireName = readWireName(choice);

  for (final String nearMiss in nearMissWireNames(
    random,
    wireName,
    choice.name,
  )) {
    if (wireNames.contains(nearMiss)) {
      continue;
    }
    expect(() => decode(nearMiss), throwsFormatException, reason: nearMiss);
  }
}

void expectRejectsWireNamesOfAnotherKind<Choice extends Enum>(
  Random random,
  List<Choice> choices,
  WireNameDecoder<Choice> decode,
) {
  final String wireName = readWireName(pickOne(random, choices));
  final List<Object?> otherKinds = <Object?>[
    null,
    random.nextBool(),
    random.nextInt(choices.length),
    random.nextDouble(),
    <Object?>[wireName],
    <String, Object?>{wireName: wireName},
  ];

  for (final Object? otherKind in otherKinds) {
    expect(() => decode(otherKind), throwsFormatException);
  }
}

String readWireName(Enum choice) {
  final Object namedChoice = choice;
  if (namedChoice is WireNamed) {
    return namedChoice.wireName;
  }
  throw ArgumentError.value(choice, 'choice', 'has no wire name');
}
