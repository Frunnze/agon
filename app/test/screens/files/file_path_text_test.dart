import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';

import '../../support/random_inputs.dart';

const int _kilobyte = 1024;
const int _gigabyte = 1024 * 1024 * 1024;
const double _allowedRoundingShare = 0.05;
const List<String> _segmentWords = <String>[
  'src',
  'auth',
  '.github',
  'README.md',
  'login.ts',
  'a b',
  'Ünïcødé',
  'x',
];
const Map<String, int> _unitSizes = <String, int>{
  'B': 1,
  'KB': _kilobyte,
  'MB': _kilobyte * _kilobyte,
  'GB': _gigabyte,
};
final RegExp _sizePattern = RegExp(r'^(\d+(?:\.\d)?) (B|KB|MB|GB)$');

List<String> _randomSegments(Random random) {
  return <String>[
    for (int index = 0; index <= random.nextInt(5); index += 1)
      pickOne(random, _segmentWords),
  ];
}

String _randomLine(Random random) {
  return randomText(random).replaceAll('\n', '').replaceAll('\r', '');
}

int _randomByteCount(Random random) {
  final int magnitude = random.nextInt(4);
  final int unit = <int>[
    1,
    _kilobyte,
    _kilobyte * _kilobyte,
    _gigabyte,
  ][magnitude];
  return random.nextInt(_kilobyte) * unit + random.nextInt(unit);
}

void main() {
  test('test_describe_file_size_property_matches_the_design_samples', () {
    expect(describeFileSize(940), '940 B');
    expect(describeFileSize(2150), '2.1 KB');
    expect(describeFileSize(88064), '86 KB');
    expect(describeFileSize(421888), '412 KB');
    expect(describeFileSize(25794970), '24.6 MB');
  });

  test('test_describe_file_size_property_stays_close_to_the_size', () {
    final Random random = seededRandom(9101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int bytes = _randomByteCount(random);
      final RegExpMatch? match = _sizePattern.firstMatch(
        describeFileSize(bytes),
      );

      expect(match, isNotNull, reason: '$bytes');
      final double shown = double.parse(match!.group(1)!);
      final int unit = _unitSizes[match.group(2)!]!;
      final double difference = (shown * unit - bytes).abs();
      expect(difference, lessThanOrEqualTo(bytes * _allowedRoundingShare));
      if (bytes < _kilobyte) {
        expect(match.group(2), 'B');
      }
    }
  });

  test('test_split_text_lines_property_round_trips_joined_lines', () {
    final Random random = seededRandom(9102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> lines = <String>[
        for (int index = 0; index <= random.nextInt(8); index += 1)
          _randomLine(random),
      ];

      expect(splitTextLines('${lines.join('\n')}\n'), lines);
      expect(splitTextLines('${lines.join('\r\n')}\r\n'), lines);
    }
    expect(splitTextLines(''), isEmpty);
  });

  test('test_split_text_lines_property_fuzz_never_keeps_line_breaks', () {
    final Random random = seededRandom(9103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = <String>[
        for (int index = 0; index < random.nextInt(6); index += 1)
          pickOne(random, <String>['\n', '\r', '\r\n', randomText(random)]),
      ].join();

      for (final String line in splitTextLines(text)) {
        expect(line.contains('\n'), isFalse);
        expect(line.endsWith('\r'), isFalse);
      }
    }
  });

  test('test_join_repository_path_property_round_trips_name_and_folder', () {
    final Random random = seededRandom(9104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> segments = _randomSegments(random);
      final String path = segments.join('/');

      expect(fileNameOf(path), segments.last);
      expect(
        parentFolderOf(path),
        segments.sublist(0, segments.length - 1).join('/'),
      );
      expect(joinRepositoryPath(parentFolderOf(path), fileNameOf(path)), path);
    }
  });

  test('test_list_ancestor_folders_property_one_prefix_per_folder', () {
    final Random random = seededRandom(9105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> segments = _randomSegments(random);
      final String path = segments.join('/');
      final List<String> ancestors = listAncestorFolders(path);

      expect(ancestors.length, segments.length);
      expect(ancestors.first, '');
      for (int index = 1; index < ancestors.length; index += 1) {
        expect(ancestors[index], segments.sublist(0, index).join('/'));
      }
    }
  });

  test('test_describe_breadcrumb_property_repository_then_folders', () {
    final Random random = seededRandom(9106);

    expect(describeBreadcrumb('acme/app', 'src/auth/redirect.ts'), <String>[
      'acme/app',
      'src',
      'auth',
    ]);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> segments = _randomSegments(random);
      final String repositoryPath = randomWordPhrase(random);
      final List<String> crumbs = describeBreadcrumb(
        repositoryPath,
        segments.join('/'),
      );

      expect(crumbs.first, repositoryPath);
      expect(crumbs.sublist(1), segments.sublist(0, segments.length - 1));
    }
  });

  test('test_read_file_extension_property_lowercase_without_dots', () {
    final Random random = seededRandom(9107);

    expect(readFileExtension('redirect.ts'), 'ts');
    expect(readFileExtension('README.MD'), 'md');
    expect(readFileExtension('.gitignore'), '');
    expect(readFileExtension('Makefile'), '');
    expect(readFileExtension('backup.tar.gz'), 'gz');
    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = readFileExtension(randomText(random));

      expect(extension.contains('.'), isFalse);
      expect(extension, extension.toLowerCase());
    }
  });

  test('test_choose_text_viewer_property_markdown_code_or_plain', () {
    final Random random = seededRandom(9108);

    expect(chooseTextViewer('README.md'), TextViewer.markdown);
    expect(chooseTextViewer('notes.markdown'), TextViewer.markdown);
    expect(chooseTextViewer('redirect.ts'), TextViewer.code);
    expect(chooseTextViewer('package.json'), TextViewer.code);
    expect(chooseTextViewer('.gitignore'), TextViewer.plain);
    expect(chooseTextViewer('LICENSE'), TextViewer.plain);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomText(random);
      final TextViewer viewer = chooseTextViewer(name);
      final String extension = readFileExtension(name);

      expect(
        viewer == TextViewer.markdown,
        extension == 'md' || extension == 'markdown',
      );
      expect(
        viewer == TextViewer.code,
        findSyntaxLanguageFor(name) != null && viewer != TextViewer.markdown,
      );
    }
  });

  test('test_describe_known_file_kind_property_names_media_by_extension', () {
    final Random random = seededRandom(9109);

    expect(describeKnownFileKind('onboarding.mp4'), 'a video');
    expect(describeKnownFileKind('theme.MP3'), 'an audio file');
    expect(describeKnownFileKind('backup.tar.gz'), 'an archive');
    expect(describeKnownFileKind('guide.pdf'), 'a PDF');
    expect(describeKnownFileKind('icon.png'), isNull);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? kind = describeKnownFileKind(randomText(random));

      expect(kind == null || kind.startsWith('a'), isTrue);
    }
  });
}
