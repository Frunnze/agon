import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_colors.dart';

import '../../support/app_harness.dart';
import 'file_screen_steps.dart';

const String _releaseParagraph =
    'The release workflow builds on mac-studio and asks for approval before '
    'it pushes.';
const String _noRunnerExplanation =
    "Files come from a runner's copy of the repository, so the app server "
    'never sees your code. Only old-macbook has a copy of acme/api, and it '
    'was last seen 3 days ago.';
const String _noRunnerAdvice =
    'Turn it on, or start a task on acme/api so another runner makes a copy. '
    'The files open here as soon as one is online.';
const String _videoSentence =
    'The viewer shows code, images, Markdown and plain text. This file is a '
    'video.';
const List<String> _headerTexts = <String>['acme-app', 'Files', 'Read only'];
const List<String> _pickerTexts = <String>[
  'Repository',
  'acme/app',
  'Branch',
  'From office-server · encrypted',
];
const List<String> _rootTreeTexts = <String>[
  '.github',
  'android',
  'assets',
  'ios',
  'src',
  '.gitignore',
  '312 B',
  'package.json',
  '1.9 KB',
  'README.md',
  '3.2 KB',
  'tsconfig.json',
  '618 B',
];
const List<String> _authTreeTexts = <String>[
  'auth',
  'login.ts',
  '2.1 KB',
  'redirect.ts',
  '940 B',
  'session.ts',
  '3.8 KB',
  'components',
  'screens',
  'App.tsx',
  '1.2 KB',
  'index.ts',
  '214 B',
];
const List<String> _assetTreeTexts = <String>[
  'fonts',
  'icon.png',
  '86 KB',
  'onboarding.mp4',
  '24.6 MB',
  'splash.png',
  '412 KB',
];
const List<String> _readmeTexts = <String>[
  'The acme mobile app for iOS and Android, built with React Native.',
  'Get started',
  'Install Node 20 and Xcode 16.',
  'Install the packages, then start the iOS app:',
  'npm install',
  'npm run ios',
  'Project layout',
  'src/auth: sign-in, sessions and redirects',
  'src/screens: one file per screen',
  'assets: icons, fonts and the onboarding video',
  'Releases',
  _releaseParagraph,
];
const List<String> _codeTexts = <String>[
  'import { Router } from "../router";',
  'const LOGIN_PATH = "/login";',
  'export function readReturnPath(search: string): string {',
  '    returnPath.startsWith("/") && !returnPath.startsWith("//");',
  '  router.replace(readReturnPath(search));',
  '1',
  '37',
];
const List<String> _noRunnerTexts = <String>[
  'acme-app',
  'Files',
  'Read only',
  'Repository',
  'acme/api',
  'No runner with acme/api is online',
  _noRunnerExplanation,
  _noRunnerAdvice,
  'Try again',
  'See runners',
];

TextSpan? _findSpan(String lineText, String spanText) {
  final RichText line =
      find
              .byWidgetPredicate(
                (Widget widget) =>
                    widget is RichText &&
                    widget.text.toPlainText() == lineText,
              )
              .evaluate()
              .single
              .widget
          as RichText;
  TextSpan? found;
  line.text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == spanText) {
      found = span;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    final bool isDesktop = size == desktopSize;

    testWidgets('project files match the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);
      await openTreePath(tester, <String>['src', 'auth']);

      expectTexts(<String>[
        ..._headerTexts,
        ..._pickerTexts,
        'main',
        ..._rootTreeTexts,
        ..._authTreeTexts,
      ]);
      if (isDesktop) {
        expectTexts(_readmeTexts);
      } else {
        expectNoTexts(_readmeTexts);
      }
    });

    testWidgets('code file matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);
      await choosePickerOption(
        tester,
        label: 'Branch',
        option: fixLoginBranch,
      );
      await openTreePath(tester, <String>['src', 'auth', 'redirect.ts']);

      expectTexts(<String>[
        'acme/app',
        'src',
        'auth',
        'redirect.ts',
        '$fixLoginBranch · 37 lines · 940 B',
        'Copy path',
        ..._codeTexts,
      ]);
      expect(
        _findSpan(_codeTexts[1], 'const')?.style?.color,
        AppColors.action,
      );
      expect(
        _findSpan(_codeTexts[1], '"/login"')?.style?.color,
        AppColors.attention,
      );
      if (isDesktop) {
        expectTexts(<String>[..._pickerTexts, ..._authTreeTexts]);
      } else {
        expectNoTexts(<String>['Repository', 'Branch', 'login.ts']);
      }
    });

    testWidgets('image file matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);
      await openTreePath(tester, <String>['assets', 'icon.png']);

      expectTexts(<String>[
        'acme/app',
        'assets',
        'icon.png',
        'main · 1024 × 1024 · 86 KB',
        'Copy path',
      ]);
      expect(find.byType(Image), findsOneWidget);
      if (isDesktop) {
        expectTexts(_assetTreeTexts);
      }
    });

    testWidgets('markdown file matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);
      await tapTreeRow(tester, 'README.md');

      expectTexts(<String>[
        'acme/app',
        'README.md',
        'main · 3.2 KB',
        'Copy path',
        'acme-app',
        ..._readmeTexts,
      ]);
    });

    testWidgets('unsupported file matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: appFilesRoute);
      await openTreePath(tester, <String>['assets', 'onboarding.mp4']);

      expectTexts(<String>[
        'acme/app',
        'assets',
        'onboarding.mp4',
        'main · 24.6 MB',
        'Copy path',
        "Can't preview this file",
        _videoSentence,
        'Copy its path to find it in your own clone of acme/app.',
      ]);
    });

    testWidgets('no runner state matches the gallery at ${size.width}', (
      WidgetTester tester,
    ) async {
      await openFiles(tester, size: size, route: apiFilesRoute);

      expectTexts(_noRunnerTexts);
      expectNoTexts(<String>['Branch', 'From office-server · encrypted']);
    });
  }
}
