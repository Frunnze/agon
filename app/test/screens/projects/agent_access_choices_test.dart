import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/app_harness.dart';

const String _pushTitle = 'Read and push';
const String _pushDetail = 'Agents push their branch when their work is done.';

void main() {
  test(
    'test_build_agent_access_choices_property_push_reads_read_and_push',
    () {
      final List<ChoiceOption<AgentAccess>> choices =
          buildAgentAccessChoices();

      expect(
        choices.map((ChoiceOption<AgentAccess> choice) => choice.value),
        AgentAccess.values,
      );
      for (final ChoiceOption<AgentAccess> choice in choices) {
        expect(choice.title, describeAgentAccessChoiceTitle(choice.value));
      }
      expect(choices.last.title, _pushTitle);
      expect(choices.last.detail, _pushDetail);
    },
  );

  testWidgets(
    'test_new_project_form_property_push_choice_reads_read_and_push',
    (WidgetTester tester) async {
      for (final Size size in <Size>[phoneSize, desktopSize]) {
        await pumpApp(
          tester,
          size: size,
          route: NewItemFormRoute(DraftKind.project),
          dependencies: buildGalleryDependencies(),
        );

        expect(find.text(_pushTitle), findsOneWidget, reason: '$size');
        expect(find.text(_pushDetail), findsOneWidget, reason: '$size');
      }
    },
  );
}
