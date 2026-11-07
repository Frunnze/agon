import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'random_inputs.dart';

const String _sharedTablePath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'rule_title_white_space_cases.json';
const int _mostTitleParts = 8;
const List<String> _lookAlikeCharacters = <String>[
  '\uFEFF',
  '\u200B',
  '\u180E',
  '\u2060',
  '\u001C',
  '\u001F',
];
const List<String> _titleWords = <String>[
  'Keep',
  'commits',
  'small',
  'café',
  'Ünïcødé',
  '!',
  '?',
  '.',
];

final class RuleTitleWhiteSpaceCase {
  const RuleTitleWhiteSpaceCase({
    required this.title,
    required this.details,
    required this.isBlank,
    required this.collapsed,
    required this.markdown,
  });

  final String title;
  final String details;
  final bool isBlank;
  final String collapsed;
  final String markdown;
}

final class RuleTitleWhiteSpaceTable {
  const RuleTitleWhiteSpaceTable({
    required this.whiteSpace,
    required this.cases,
  });

  final List<String> whiteSpace;
  final List<RuleTitleWhiteSpaceCase> cases;

  bool isWhiteSpace(String character) => whiteSpace.contains(character);

  String trimByModel(String text) {
    final List<String> characters = text.split('');
    int start = 0;
    int end = characters.length;
    while (start < end && isWhiteSpace(characters[start])) {
      start += 1;
    }
    while (end > start && isWhiteSpace(characters[end - 1])) {
      end -= 1;
    }
    return characters.sublist(start, end).join();
  }

  String collapseByModel(String text) {
    final List<String> words = <String>[];
    final StringBuffer word = StringBuffer();
    for (final String character in text.split('')) {
      if (!isWhiteSpace(character)) {
        word.write(character);
        continue;
      }
      if (word.isNotEmpty) {
        words.add(word.toString());
        word.clear();
      }
    }
    if (word.isNotEmpty) {
      words.add(word.toString());
    }
    return words.join(' ');
  }

  String randomWhiteSpaceRun(Random random) {
    final int length = random.nextInt(4);
    final StringBuffer run = StringBuffer();
    for (int i = 0; i < length; i += 1) {
      run.write(pickOne(random, whiteSpace));
    }
    return run.toString();
  }

  String randomExoticTitle(Random random) {
    final int partCount = random.nextInt(_mostTitleParts);
    final StringBuffer title = StringBuffer();
    for (int i = 0; i < partCount; i += 1) {
      final String part = pickOne(random, <String>[
        randomWhiteSpaceRun(random),
        pickOne(random, _lookAlikeCharacters),
        pickOne(random, _titleWords),
        randomText(random),
      ]);
      title.write(part);
    }
    return title.toString();
  }
}

String _readText(Map<String, Object?> entry, String field) {
  final Object? text = entry[field];
  if (text is! String) {
    throw FormatException('a shared rule title case has no $field: $entry');
  }
  return text;
}

RuleTitleWhiteSpaceCase _readCase(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('a shared rule title case is not an object: $entry');
  }
  final Object? isBlank = entry['is_blank'];
  if (isBlank is! bool) {
    throw FormatException('a shared rule title case has no is_blank: $entry');
  }
  return RuleTitleWhiteSpaceCase(
    title: _readText(entry, 'title'),
    details: _readText(entry, 'details'),
    isBlank: isBlank,
    collapsed: _readText(entry, 'collapsed'),
    markdown: _readText(entry, 'markdown'),
  );
}

RuleTitleWhiteSpaceTable readRuleTitleWhiteSpaceTable() {
  final String tableText = File(_sharedTablePath).readAsStringSync();
  final Object? table = jsonDecode(tableText);
  if (table is! Map<String, Object?>) {
    throw const FormatException('the shared rule title table is no object');
  }
  final Object? whiteSpace = table['white_space'];
  final Object? cases = table['cases'];
  if (whiteSpace is! String || cases is! List<Object?>) {
    throw const FormatException('the shared rule title table is malformed');
  }
  return RuleTitleWhiteSpaceTable(
    whiteSpace: whiteSpace.split(''),
    cases: <RuleTitleWhiteSpaceCase>[
      for (final Object? entry in cases) _readCase(entry),
    ],
  );
}
