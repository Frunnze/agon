import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/list_harness.dart';
import '../support/random_inputs.dart';

const SkillDetailRoute _iosReleaseRoute = SkillDetailRoute(
  GallerySkillIds.iosRelease,
);
const SkillId _changedSkillId = SkillId('skill-changed');
const String _personEditTitle = 'Changed by you';
const String _approvedTitle = 'Improved by an agent, approved by you';
const String _automaticTitle = 'Improved by an agent automatically';
const List<String> _rowTitles = <String>[
  _personEditTitle,
  _approvedTitle,
  _automaticTitle,
];
const int _shownChangeCount = 5;

const List<String> _galleryHistoryTexts = <String>[
  'Agents may improve it',
  'Ask me',
  'History',
  _approvedTitle,
  'release #41 · 2 h ago',
  _automaticTitle,
  '3 days ago',
  _personEditTitle,
  '5 days ago',
];

SkillChangeOrigin _randomOrigin(Random random) {
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    const ApprovedAgentRun(GalleryRunIds.release41),
    const AutomaticAgentRun(RunId('run-unknown')),
  ]);
}

List<SkillChange> _randomHistory(Random random) {
  final int count = random.nextInt(8);
  return <SkillChange>[
    for (int i = 0; i < count; i += 1)
      SkillChange(
        origin: _randomOrigin(random),
        savedAt: galleryDaysAgo(count - i + 1),
        replacedInstructions: 'Version $i',
      ),
  ];
}

Skill _buildChangedSkill(List<SkillChange> history) {
  return Skill(
    id: _changedSkillId,
    name: 'changed',
    summary: 'A skill with changes',
    instructions: 'Current version',
    scope: const Scope.everywhere(),
    usage: SkillUsage.automatic,
    source: SkillSource.created,
    improvement: SkillImprovement.auto,
    history: history,
  );
}

int _countRowTitles() {
  int count = 0;
  for (final String title in _rowTitles) {
    count += find.text(title).evaluate().length;
  }
  return count;
}

void main() {
  for (final Size size in <Size>[phoneSize, desktopSize]) {
    testWidgets('skill history matches the design at ${size.width}', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        route: _iosReleaseRoute,
        dependencies: buildGalleryDependencies(),
      );

      for (final String text in _galleryHistoryTexts) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Undo'), findsOneWidget);
    });
  }

  testWidgets('undo restores the version before each agent change', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    await pumpApp(
      tester,
      size: desktopSize,
      route: _iosReleaseRoute,
      dependencies: dependencies,
    );
    final List<SkillChange> history = gallerySkills.first.history;

    await tapVisible(tester, find.text('Undo'));
    await pumpFrames(tester);

    final Skill once = dependencies.skillRepository.findSkill(
      GallerySkillIds.iosRelease,
    );
    expect(once.instructions, history.last.replacedInstructions);
    expect(find.text(_approvedTitle), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tapVisible(tester, find.text('Undo'));
    await pumpFrames(tester);

    final Skill twice = dependencies.skillRepository.findSkill(
      GallerySkillIds.iosRelease,
    );
    expect(twice.instructions, history[1].replacedInstructions);
    expect(find.text(_personEditTitle), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets(
    'test_skill_history_section_property_undo_only_for_newest_agent_change',
    (WidgetTester tester) async {
      final Random random = seededRandom(9741);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<SkillChange> history = _randomHistory(random);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpApp(
          tester,
          size: desktopSize,
          route: const SkillDetailRoute(_changedSkillId),
          dependencies: buildDependenciesWithSkills(<Skill>[
            _buildChangedSkill(history),
          ]),
        );

        final bool isAgentChangeNewest =
            history.isNotEmpty && history.last.origin is AgentRunOrigin;
        final Matcher undoCount = isAgentChangeNewest
            ? findsOneWidget
            : findsNothing;
        expect(find.text('Undo'), undoCount);
        expect(_countRowTitles(), min(history.length, _shownChangeCount));
        expect(
          find.text('No changes yet.'),
          history.isEmpty ? findsOneWidget : findsNothing,
        );
        expect(find.text('Auto'), findsOneWidget);
      }
    },
  );
}
