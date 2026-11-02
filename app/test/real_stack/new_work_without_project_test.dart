import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';

import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _projectQuestion = 'What is this project, and where is its code?';
const String _missingProjectProblem = 'Create a project before adding tasks';
const Map<String, String> _newWorkButtons = <String, String>{
  'Tasks': 'New task',
  'Jobs': 'New job',
};

bool _hasNoProjects(RealStack stack) {
  final List<Project> projects = stack.dependencies.projectRepository
      .listProjects(stack.homeWorkspaceId);
  return projects.isEmpty;
}

void main() {
  testWidgets(
    'test_new_work_property_without_a_project_opens_the_new_project_chat',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      expect(_hasNoProjects(stack), isTrue);

      for (final MapEntry<String, String> section in _newWorkButtons.entries) {
        await openRailSection(
          tester,
          label: section.key,
          pageTitle: section.key,
        );
        await tapAndWait(
          tester,
          find.text(section.value).first,
          expected: find.text(_projectQuestion),
        );

        expect(tester.takeException(), isNull, reason: section.value);
        expect(find.textContaining(_missingProjectProblem), findsNothing);
      }

      await stack.close(tester);
    },
  );
}
