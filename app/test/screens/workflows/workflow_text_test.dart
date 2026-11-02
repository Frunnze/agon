import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

void main() {
  test('test_describe_availability_property_names_every_workspace', () {
    final Random random = seededRandom(8601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> chosen = <WorkspaceId>[
        if (random.nextBool()) GalleryWorkspaceIds.acme,
        if (random.nextBool()) GalleryWorkspaceIds.personal,
      ];
      final String text = describeAvailability(
        OnlyWorkspaces(chosen),
        galleryWorkspaces,
      );

      if (chosen.isEmpty) {
        expect(text, 'No workspace');
      } else {
        expect(text.split(', ').length, chosen.length);
      }
    }
    expect(
      describeAvailability(const AllWorkspaces(), galleryWorkspaces),
      'All workspaces',
    );
  });

  test('test_find_signature_state_property_change_beats_signature', () {
    for (final Workflow workflow in galleryWorkflows) {
      final WorkflowChange? change =
          workflow.id == GalleryWorkflowIds.trainRanker
          ? galleryWorkflowChanges.first
          : null;
      final SignatureState state = findSignatureState(workflow, change);

      if (workflow.signature == null) {
        expect(state, SignatureState.notSignedYet);
      } else if (change != null) {
        expect(state, SignatureState.changedNotSigned);
      } else {
        expect(state, SignatureState.signed);
      }
    }
  });

  test('test_build_signature_label_property_only_signed_is_calm', () {
    for (final SignatureState state in SignatureState.values) {
      final StatusLabel label = buildSignatureLabel(state);
      final bool isSigned = state == SignatureState.signed;

      expect(label.tone == StatusTone.muted, isSigned);
      expect(label.icon, isSigned ? AppIconKind.check : AppIconKind.alert);
    }
    expect(
      buildSignatureLabel(SignatureState.changedNotSigned).text,
      'Changed, not signed',
    );
  });

  test('test_describe_agent_target_property_lowercase_phrases', () {
    final Random random = seededRandom(8602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = <String>[
        pickOne(random, <String>['linux', 'gpu', 'mac']),
      ];
      expect(
        describeAgentTarget(RunnerWithLabels(labels), _deviceNames),
        'any ${labels.first} runner',
      );
    }
    expect(
      describeAgentTarget(
        const SpecificRunner(GalleryDeviceIds.officeServer),
        _deviceNames,
      ),
      'office-server',
    );
    expect(
      describeAgentTarget(const AnyFreeRunner(), _deviceNames),
      'any free runner',
    );
  });

  test('test_describe_agent_names_property_one_name_per_agent', () {
    final Random random = seededRandom(8603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final String names = describeAgentNames(workflow);

      if (workflow.agents.isEmpty) {
        expect(names, 'No agents yet');
      } else {
        expect(names.split(', ').length, workflow.agents.length);
      }
    }
    expect(
      describeAgentNames(galleryWorkflows[2]),
      'plan, backend, ios, review, ship',
    );
  });

  test('test_describe_last_use_property_never_without_runs', () {
    final Random random = seededRandom(8604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime moment = randomLocalMoment(random);
      expect(describeLastUse(moment, moment), 'Just now');
    }
    expect(describeLastUse(null, galleryNow), 'Never');
  });

  test('test_describe_builder_summary_property_counts_agents', () {
    expect(
      describeBuilderSummary(
        workflow: galleryWorkflows[2],
        state: SignatureState.notSignedYet,
        workspaces: galleryWorkspaces,
      ),
      '5 agents · all workspaces · not signed yet',
    );
    expect(
      describeBuilderSummary(
        workflow: galleryWorkflows[4],
        state: SignatureState.signed,
        workspaces: galleryWorkspaces,
      ),
      '1 agent · acme · signed',
    );
  });

  test('test_describe_signed_summary_property_names_signer', () {
    expect(
      describeSignedSummary(
        workflow: galleryWorkflows.first,
        workspaces: galleryWorkspaces,
        deviceNames: _deviceNames,
        now: galleryNow,
      ),
      'In acme · signed on air-laptop 3 days ago',
    );
  });

  test('test_build_runner_match_label_property_counts_online_matches', () {
    final Random random = seededRandom(8605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        for (final Runner runner in galleryRunners)
          if (random.nextBool()) runner,
      ];
      final StatusLabel label = buildRunnerMatchLabel(
        RunnerWithLabels(const <String>['mac']),
        runners,
      );
      final int matches = runners
          .where(
            (Runner runner) => runner.online && runner.labels.contains('mac'),
          )
          .length;

      if (matches == 0) {
        expect(label.text, 'No match online');
      } else {
        expect(label.text, startsWith('$matches match'));
      }
    }
    expect(
      buildRunnerMatchLabel(
        const SpecificRunner(GalleryDeviceIds.officeServer),
        galleryRunners,
      ).text,
      'Online',
    );
    expect(
      buildRunnerMatchLabel(
        const SpecificRunner(GalleryDeviceIds.oldMacbook),
        galleryRunners,
      ).text,
      'Offline',
    );
    expect(
      buildRunnerMatchLabel(const AnyFreeRunner(), galleryRunners).text,
      '3 runners online',
    );
  });
}
