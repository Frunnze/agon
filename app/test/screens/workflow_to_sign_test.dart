import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/screens/workflows/workflows_screen.dart';

import '../support/random_inputs.dart';
import '../support/random_signature_workflows.dart';

void main() {
  test(
    'test_find_workflow_to_sign_property_found_exactly_when_not_signed',
    () {
      final Random random = seededRandom(5002);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<WorkflowInSignatureState> choices =
            randomWorkflowsInSignatureStates(random);
        final TaskFormOptions options = buildTaskFormOptions(
          projects: galleryProjects,
          workflows: <Workflow>[
            for (final WorkflowInSignatureState choice in choices)
              choice.workflow,
          ],
          findPendingChange: buildSignatureStateRepository(choices)
              .findPendingChange,
          runners: galleryRunners,
          deviceNames: DeviceNames(galleryDevices),
          skills: gallerySkills,
          chosenTarget: const AnyFreeRunner(),
        );

        for (final WorkflowInSignatureState choice in choices) {
          final Workflow workflow = choice.workflow;
          final WorkflowToSign? toSign = options.findWorkflowToSign(
            WorkflowDoer(workflow.id),
          );
          expect(toSign == null, choice.isSigned);
          expect(toSign?.name, choice.isSigned ? null : workflow.name);
          expect(
            toSign?.signRoute,
            choice.isSigned
                ? null
                : findWorkflowRoute(workflow.id, choice.state),
          );
        }
        final OneAgentDoer agentDoer = OneAgentDoer(
          pickOne(random, AgentKind.values),
        );
        expect(options.findWorkflowToSign(agentDoer), isNull);
      }
    },
  );

  test('test_find_workflows_to_sign_property_keys_are_the_unsigned_ids', () {
    final Random random = seededRandom(5004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowInSignatureState> choices =
          randomWorkflowsInSignatureStates(random);
      final Map<WorkflowId, WorkflowToSign> workflowsToSign =
          findWorkflowsToSign(
            workflows: <Workflow>[
              for (final WorkflowInSignatureState choice in choices)
                choice.workflow,
            ],
            findPendingChange: buildSignatureStateRepository(choices)
                .findPendingChange,
          );

      expect(workflowsToSign.keys.toSet(), <WorkflowId>{
        for (final WorkflowInSignatureState choice in choices)
          if (!choice.isSigned) choice.workflow.id,
      });
    }
  });
}
