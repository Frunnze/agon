import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/random_inputs.dart';

const String _viewerSentence =
    'The viewer shows code, images, Markdown and plain text. ';
const List<String> _fileNames = <String>[
  'redirect.ts',
  'README.md',
  '.gitignore',
  'onboarding.mp4',
  'icon.png',
  'notes',
];

String _joinSegments(List<TextSegment> segments) {
  return segments.map((TextSegment segment) => segment.text).join();
}

FilePreview _randomPreview(Random random) {
  return switch (random.nextInt(3)) {
    0 => TextFilePreview(
      List<String>.filled(random.nextInt(50), 'line').join('\n'),
    ),
    1 => ImageFilePreview(
      width: random.nextInt(4000),
      height: random.nextInt(4000),
      bytes: Uint8List(0),
    ),
    _ => UnavailableFilePreview(
      pickOne(random, PreviewUnavailableReason.values),
    ),
  };
}

List<String> _randomBranches(Random random, String prefix) {
  return <String>[
    for (int index = 0; index < random.nextInt(4); index += 1)
      '$prefix${randomWordPhrase(random).replaceAll(' ', '-')}$index',
  ];
}

void main() {
  test('test_describe_file_details_property_matches_the_design_samples', () {
    final String redirect = List<String>.filled(37, 'x').join('\n');

    expect(
      describeFileDetails(
        RepositoryFile(
          path: 'src/auth/redirect.ts',
          size: 940,
          preview: TextFilePreview(redirect),
        ),
      ),
      '37 lines · 940 B',
    );
    expect(
      describeFileDetails(
        RepositoryFile(
          path: 'assets/icon.png',
          size: 88064,
          preview: ImageFilePreview(
            width: 1024,
            height: 1024,
            bytes: Uint8List(0),
          ),
        ),
      ),
      '1024 × 1024 · 86 KB',
    );
    expect(
      describeFileDetails(
        const RepositoryFile(
          path: 'README.md',
          size: 3277,
          preview: TextFilePreview('# acme-app'),
        ),
      ),
      '3.2 KB',
    );
  });

  test('test_describe_file_details_property_always_ends_with_the_size', () {
    final Random random = seededRandom(9301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryFile file = RepositoryFile(
        path: 'folder/${pickOne(random, _fileNames)}',
        size: random.nextInt(1 << 30),
        preview: _randomPreview(random),
      );

      expect(describeFileDetails(file), endsWith(describeFileSize(file.size)));
    }
  });

  test('test_describe_file_summary_property_starts_with_the_branch', () {
    final Random random = seededRandom(9302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String branch = pickOne(random, <String>['main', 'task/x-1']);
      final RepositoryFile file = RepositoryFile(
        path: pickOne(random, _fileNames),
        size: random.nextInt(1 << 20),
        preview: _randomPreview(random),
      );
      final List<TextSegment> summary = describeFileSummary(
        branch: branch,
        file: file,
      );

      expect(summary.first.text, branch);
      expect(summary.first.face, TextFace.monospace);
      final String details = describeFileDetails(file);
      expect(_joinSegments(summary), '$branch · $details');
    }
  });

  test('test_describe_unavailable_preview_property_names_the_reason', () {
    final Random random = seededRandom(9303);

    expect(
      describeUnavailablePreview(
        fileName: 'onboarding.mp4',
        reason: PreviewUnavailableReason.tooLarge,
      ),
      '${_viewerSentence}This file is a video.',
    );
    expect(
      describeUnavailablePreview(
        fileName: 'data.bin',
        reason: PreviewUnavailableReason.binary,
      ),
      '${_viewerSentence}This file is not text.',
    );
    for (int i = 0; i < propertyIterations; i += 1) {
      final String sentence = describeUnavailablePreview(
        fileName: randomText(random),
        reason: pickOne(random, PreviewUnavailableReason.values),
      );

      expect(sentence, startsWith('${_viewerSentence}This file is '));
      expect(sentence, endsWith('.'));
    }
  });

  test('test_choose_initial_branch_property_prefers_request_then_default', () {
    final Random random = seededRandom(9304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = FilesFromRunner(
        runnerId: const DeviceId('runner'),
        runnerName: 'office-server',
        branches: _randomBranches(random, ''),
        taskBranches: _randomBranches(random, 'task/'),
      );
      final List<String> all = <String>[
        ...source.branches,
        ...source.taskBranches,
      ];
      final String? requested = pickOne(random, <String?>[
        null,
        'missing-branch',
        if (all.isNotEmpty) pickOne(random, all),
      ]);
      final String defaultBranch = random.nextBool() && all.isNotEmpty
          ? pickOne(random, all)
          : 'main';
      final String? chosen = chooseInitialBranch(
        source: source,
        requestedBranch: requested,
        defaultBranch: defaultBranch,
      );

      if (all.isEmpty) {
        expect(chosen, isNull);
      } else if (requested != null && all.contains(requested)) {
        expect(chosen, requested);
      } else if (all.contains(defaultBranch)) {
        expect(chosen, defaultBranch);
      } else {
        expect(chosen, all.first);
      }
    }
  });

  test('test_build_branch_entries_property_groups_both_kinds', () {
    final Random random = seededRandom(9305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = FilesFromRunner(
        runnerId: const DeviceId('runner'),
        runnerName: 'office-server',
        branches: _randomBranches(random, ''),
        taskBranches: _randomBranches(random, 'task/'),
      );
      final List<SelectEntry<String>> entries = buildBranchEntries(source);
      final List<String> headings = <String>[
        for (final SelectEntry<String> entry in entries)
          if (entry is SelectGroupHeading<String>) entry.label,
      ];
      final List<String> options = <String>[
        for (final SelectEntry<String> entry in entries)
          if (entry is SelectOption<String>) entry.value,
      ];

      expect(options, <String>[...source.branches, ...source.taskBranches]);
      expect(headings, <String>[
        if (source.branches.isNotEmpty) 'Branches',
        if (source.taskBranches.isNotEmpty) 'Task branches',
      ]);
    }
  });

  test('test_describe_own_clone_hint_property_names_the_repository', () {
    final Random random = seededRandom(9306);

    expect(
      describeOwnCloneHint('acme/app'),
      'Copy its path to find it in your own clone of acme/app.',
    );
    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomWordPhrase(random);

      expect(
        describeOwnCloneHint(repositoryPath),
        endsWith('$repositoryPath.'),
      );
    }
  });
}
