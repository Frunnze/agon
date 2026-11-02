import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';

const String _galleryConfirmationMethod = 'Touch ID';

void main() {
  test(
    'test_build_agent_access_choices_property_names_the_approval_method',
    () {
      final Random random = seededRandom(8001);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String methodName = randomText(random);
        final List<ChoiceOption<AgentAccess>> choices =
            buildAgentAccessChoices(confirmationMethodName: methodName);

        expect(
          choices.map((ChoiceOption<AgentAccess> choice) => choice.value),
          AgentAccess.values,
        );
        for (final ChoiceOption<AgentAccess> choice in choices) {
          expect(choice.title, describeAgentAccessChoiceTitle(choice.value));
        }
        final ChoiceOption<AgentAccess> pushChoice = choices.last;
        expect(
          pushChoice.detail,
          'The hub pushes for the agent after you approve with $methodName.',
        );
      }
    },
  );

  testWidgets('test_new_project_form_property_names_the_approval_method', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[phoneSize, desktopSize]) {
      await pumpApp(
        tester,
        size: size,
        route: NewItemFormRoute(DraftKind.project),
        dependencies: buildGalleryDependencies(),
      );

      expect(
        find.text(
          'The hub pushes for the agent after you approve with '
          '$_galleryConfirmationMethod.',
        ),
        findsOneWidget,
        reason: '$size',
      );
    }
  });
}
