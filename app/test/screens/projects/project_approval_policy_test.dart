import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

const String _sameAsWorkspaceTitle = 'Same as the workspace';
const Map<ApprovalPolicy?, String> _choiceTitles = <ApprovalPolicy?, String>{
  null: _sameAsWorkspaceTitle,
  ApprovalPolicy.neverAsk: 'Auto',
  ApprovalPolicy.askBeforeRiskyActions: 'Ask me',
};
const List<String> _fieldTexts = <String>[
  'Commands and pushes',
  _sameAsWorkspaceTitle,
  'Uses the workspace setting in Settings.',
  'Auto',
  'Runs commands and pushes without asking you.',
  'Ask me',
  'Asks you before each command and each push.',
];

Future<AppDependencies> _pumpNewProject(WidgetTester tester) async {
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    projectRepository: FakeProjectRepository(projects: const <Project>[]),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const NewProjectRoute(),
    dependencies: dependencies,
  );
  return dependencies;
}

Future<Project> _createProject(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  await enterFieldText(
    tester,
    label: 'Repos',
    text: 'github.com/acme/approvals',
  );
  await tapVisible(tester, find.text('Add repo'));
  await pumpFrames(tester);
  await tapVisible(tester, find.text('Create project'));
  await pumpFrames(tester);

  return dependencies.projectRepository
      .listProjects(GalleryWorkspaceIds.acme)
      .single;
}

void main() {
  testWidgets('the project form shows the commands field after access', (
    WidgetTester tester,
  ) async {
    await _pumpNewProject(tester);

    for (final String text in _fieldTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final double accessTop = tester
        .getTopLeft(find.text('What agents can do'))
        .dy;
    final double policyTop = tester
        .getTopLeft(find.text('Commands and pushes'))
        .dy;
    expect(policyTop, greaterThan(accessTop));
  });

  testWidgets('a new project saved untouched follows the workspace', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = await _pumpNewProject(tester);

    final Project created = await _createProject(tester, dependencies);

    expect(created.approvalPolicy, isNull);
  });

  testWidgets('test_project_form_property_saves_the_tapped_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9821);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);
      final AppDependencies dependencies = await _pumpNewProject(tester);

      await tapVisible(tester, find.text(_choiceTitles[chosen]!));
      await pumpFrames(tester);
      final Project created = await _createProject(tester, dependencies);

      expect(created.approvalPolicy, chosen);
    }
  });
}
