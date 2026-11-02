import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_screen_steps.dart';

const double _largestImageWidth = 256;
const double _widestRepositoryPicker = 200;
const double _pickerHeight = 10;
const Key _repositoryKey = Key('repository');
const Key _branchKey = Key('branch');

void main() {
  testWidgets('test_file_pickers_property_repository_hugs_its_content', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      final double repositoryWidth = randomWidth(
        random,
        least: 0,
        most: width * 2,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: SizedBox(
            key: _repositoryKey,
            width: repositoryWidth,
            height: _pickerHeight,
          ),
          branch: const SizedBox(key: _branchKey, height: _pickerHeight),
        ),
      );

      final Rect repository = tester.getRect(find.byKey(_repositoryKey));
      final Rect branch = tester.getRect(find.byKey(_branchKey));
      final double widest = width - AppSpacing.space3;
      expect(repository.width, closeTo(min(repositoryWidth, widest), 0.01));
      expect(branch.left - repository.right, closeTo(AppSpacing.space3, 0.01));
      expect(branch.right, closeTo(width, 0.01));
    }
  });

  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('repository picker hugs its options at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);

      final Rect repository = tester.getRect(find.byType(RepositoryPicker));
      final Rect branch = tester.getRect(find.byType(BranchPicker));
      expect(repository.width, lessThan(_widestRepositoryPicker));
      expect(branch.left - repository.right, AppSpacing.space3);
    });

    testWidgets('no runner repository picker hugs its options at '
        '${size.width}', (WidgetTester tester) async {
      await openFiles(tester, size: size, route: apiFilesRoute);

      final Rect repository = tester.getRect(find.byType(RepositoryPicker));
      expect(repository.width, lessThan(_widestRepositoryPicker));
    });
  }

  testWidgets('readme size reads at body size', (WidgetTester tester) async {
    await openFiles(tester, size: desktopSize, route: appFilesRoute);

    final Text size = tester.widget(
      find.descendant(
        of: find.byType(ReadmeSection),
        matching: find.text('3.2 KB'),
      ),
    );
    expect(size.style?.fontSize, AppFontSizes.body);
  });

  testWidgets('image preview is as wide as the design art', (
    WidgetTester tester,
  ) async {
    await openFiles(tester, size: desktopSize, route: appFilesRoute);
    await openTreePath(tester, <String>['assets', 'icon.png']);

    expect(tester.getSize(find.byType(Image)).width, _largestImageWidth);
  });
}
