import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

RefusedActionCase _buildSwitchRuleCase() {
  late RuleRepository ruleRepository;
  late bool wasEnabled;

  return RefusedActionCase(
    functionName: 'switch_rule',
    actionLabel: changeSettingLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      ruleRepository = RefusingRuleRepository(
        stored: gallery.ruleRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const SectionRoute(AppSection.rules),
        dependencies: replaceRepositories(
          gallery,
          ruleRepository: ruleRepository,
        ),
      );
    },
    performAction: (tester) async {
      final Finder firstSwitch = find.byType(SwitchToggle).first;
      wasEnabled = tester.widget<SwitchToggle>(firstSwitch).value;
      await tester.ensureVisible(firstSwitch);
      await tester.tap(firstSwitch);
      await pumpFrames(tester);
    },
    expectSucceeded: (tester) {
      final List<bool> shownStates = <bool>[
        for (final Rule rule in ruleRepository.listRules()) rule.enabled,
      ];
      final SwitchToggle firstSwitch = tester.widget<SwitchToggle>(
        find.byType(SwitchToggle).first,
      );
      expect(firstSwitch.value, !wasEnabled);
      expect(shownStates, contains(!wasEnabled));
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildSwitchRuleCase(), seed: 91711);
}
