import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../support/random_inputs.dart';

const int _largestAgeInMinutes = 60 * 24 * 9;
const String _missingValueText = 'null';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

DateTime _randomPastMoment(Random random) {
  final int ageInMinutes = random.nextInt(_largestAgeInMinutes);
  return galleryNow.subtract(Duration(minutes: ageInMinutes));
}

DateTime? _randomOptionalMoment(Random random) {
  return random.nextBool() ? null : _randomPastMoment(random);
}

String _describeSince(DateTime moment) {
  return lowercaseFirstLetter(describeTimeSince(moment, galleryNow));
}

Workflow _withSignature(Workflow template, WorkflowSignature signature) {
  return Workflow(
    id: template.id,
    name: template.name,
    availability: template.availability,
    agents: template.agents,
    connections: template.connections,
    signature: signature,
  );
}

WorkflowSignature _randomSignature(Random random, DateTime? signedAt) {
  final Device signer = pickOne(random, galleryDevices);
  return WorkflowSignature(
    signedBy: signer.id,
    signature: const <int>[1, 2],
    signedDocument: randomText(random),
    signedAt: signedAt,
  );
}

WorkflowChange _randomChange(Random random) {
  final WorkflowChange template = galleryWorkflowChanges.first;
  final DeviceId? changedBy = random.nextBool()
      ? null
      : pickOne(random, galleryDevices).id;
  return WorkflowChange(
    workflowId: template.workflowId,
    changedBy: changedBy,
    changedAt: _randomOptionalMoment(random),
    summary: template.summary,
    differences: template.differences,
    signedDocument: template.signedDocument,
    changedDocument: template.changedDocument,
  );
}

void main() {
  test(
    'test_describe_signed_summary_property_unknown_moment_names_signer',
    () {
      final Random random = seededRandom(75201);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow template = pickOne(random, galleryWorkflows);
        final DateTime signedAt = _randomPastMoment(random);
        final WorkflowSignature known = _randomSignature(random, signedAt);
        final WorkflowSignature unknown = WorkflowSignature(
          signedBy: known.signedBy,
          signature: known.signature,
          signedDocument: known.signedDocument,
          signedAt: null,
        );

        final String knownText = describeSignedSummary(
          workflow: _withSignature(template, known),
          workspaces: galleryWorkspaces,
          deviceNames: _deviceNames,
          now: galleryNow,
        );
        final String unknownText = describeSignedSummary(
          workflow: _withSignature(template, unknown),
          workspaces: galleryWorkspaces,
          deviceNames: _deviceNames,
          now: galleryNow,
        );

        expect(knownText, '$unknownText ${_describeSince(signedAt)}');
        expect(unknownText, endsWith(_deviceNames.nameOf(known.signedBy)));
      }
    },
  );

  test('test_describe_change_summary_property_unknown_parts_are_left_out', () {
    final Random random = seededRandom(75202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChange change = _randomChange(random);
      final DateTime? changedAt = change.changedAt;
      final DeviceId? changedBy = change.changedBy;

      final String text = describeChangeSummary(
        change: change,
        deviceNames: _deviceNames,
        now: galleryNow,
      );

      final List<String> expectedParts = <String>[
        'Changed',
        if (changedAt != null) _describeSince(changedAt),
        if (changedBy != null) 'on ${_deviceNames.nameOf(changedBy)}',
      ];
      expect(text, expectedParts.join(' '));
      expect(text, isNot(contains(_missingValueText)));
    }
  });

  test('test_describe_kept_version_property_unknown_moment_keeps_promise', () {
    final Random random = seededRandom(75203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime? signedAt = _randomOptionalMoment(random);
      final WorkflowSignature signature = _randomSignature(random, signedAt);

      final String text = describeKeptVersion(signature, galleryNow);

      expect(text, startsWith('Until then, runners keep using the '));
      expect(text, isNot(contains(_missingValueText)));
      if (signedAt == null) {
        expect(text, 'Until then, runners keep using the signed version.');
      } else {
        expect(text, contains(_describeSince(signedAt)));
      }
    }
  });
}
