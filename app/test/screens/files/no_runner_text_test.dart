import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';

const String _preface =
    "Files come from a runner's copy of the repository, so the app server "
    'never sees your code.';
const String _openingPromise = 'The files open here as soon as one is online.';
const List<String> _runnerNames = <String>[
  'old-macbook',
  'mac-studio',
  'gpu-box',
  'office-server',
];
final DateTime _now = DateTime(2026, 10, 29, 14, 9, 40);

List<RepositoryHolder> _randomHolders(Random random) {
  return <RepositoryHolder>[
    for (int index = 0; index < random.nextInt(4); index += 1)
      RepositoryHolder(
        deviceId: DeviceId('device-$index'),
        name: pickOne(random, _runnerNames),
        lastSeen: _now.subtract(Duration(minutes: random.nextInt(10000))),
      ),
  ];
}

String _joinSegments(List<TextSegment> segments) {
  return segments.map((TextSegment segment) => segment.text).join();
}

void main() {
  test('test_describe_no_runner_explanation_property_matches_the_design', () {
    final List<TextSegment> explanation = describeNoRunnerExplanation(
      holders: <RepositoryHolder>[
        RepositoryHolder(
          deviceId: const DeviceId('old'),
          name: 'old-macbook',
          lastSeen: _now.subtract(const Duration(days: 3)),
        ),
      ],
      repositoryPath: 'acme/api',
      now: _now,
    );

    expect(
      _joinSegments(explanation),
      '$_preface Only old-macbook has a copy of acme/api, and it was last '
      'seen 3 days ago.',
    );
    expect(
      describeNoRunnerTitle('acme/api'),
      'No runner with acme/api is online',
    );
    expect(
      describeNoRunnerAdvice(holderCount: 1, repositoryPath: 'acme/api'),
      'Turn it on, or start a task on acme/api so another runner makes a '
      'copy. $_openingPromise',
    );
  });

  test('test_describe_no_runner_explanation_property_names_every_holder', () {
    final Random random = seededRandom(9401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryHolder> holders = _randomHolders(random);
      final String repositoryPath = randomWordPhrase(random);
      final List<TextSegment> explanation = describeNoRunnerExplanation(
        holders: holders,
        repositoryPath: repositoryPath,
        now: _now,
      );
      final List<String> monospaceTexts = <String>[
        for (final TextSegment segment in explanation)
          if (segment.face == TextFace.monospace) segment.text,
      ];
      final String sentence = _joinSegments(explanation);

      expect(monospaceTexts, <String>[
        for (final RepositoryHolder holder in holders) holder.name,
      ]);
      expect(sentence, startsWith(_preface));
      expect(sentence, contains(repositoryPath));
      expect(sentence, endsWith('.'));
      expect(
        sentence.contains(' Just') || sentence.contains(' Yester'),
        isFalse,
      );
      if (holders.isEmpty) {
        expect(
          sentence,
          endsWith('No runner has a copy of $repositoryPath yet.'),
        );
      }
    }
  });

  test('test_describe_no_runner_advice_property_ends_with_the_promise', () {
    final Random random = seededRandom(9402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int holderCount = random.nextInt(5);
      final String repositoryPath = randomWordPhrase(random);
      final String advice = describeNoRunnerAdvice(
        holderCount: holderCount,
        repositoryPath: repositoryPath,
      );

      expect(advice, endsWith(_openingPromise));
      expect(advice, contains('a task on $repositoryPath'));
      expect(advice.startsWith('Turn it on'), holderCount == 1);
      expect(advice.startsWith('Turn one on'), holderCount > 1);
    }
  });

  test('test_describe_no_runner_title_property_names_the_repository', () {
    final Random random = seededRandom(9403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomWordPhrase(random);

      expect(
        describeNoRunnerTitle(repositoryPath),
        'No runner with $repositoryPath is online',
      );
    }
  });
}
