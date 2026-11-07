import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/workflow_signed_content.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';
import 'support/workflow_signing_inputs.dart';

void main() {
  test('test_sign_fake_workflow_property_pending_change_document_'
      'wins', () {
    final Random random = seededRandom(95181);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomMaybeSignedWorkflow(random, i);
      final WorkflowChange change = randomChangeFor(random, workflow.id);

      final WorkflowSignature signed = signFakeWorkflow(
        workflow: workflow,
        pendingChange: change,
        signedBy: DeviceId(randomText(random)),
        signedAt: randomUtcMoment(random),
      );

      expect(signed.signedDocument, change.changedDocument);
    }
  });

  test('test_sign_fake_workflow_property_keeps_the_signed_document_'
      'without_change', () {
    final Random random = seededRandom(95182);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomSignedWorkflow(random, i);

      final WorkflowSignature signed = signFakeWorkflow(
        workflow: workflow,
        pendingChange: null,
        signedBy: DeviceId(randomText(random)),
        signedAt: randomUtcMoment(random),
      );

      expect(signed.signedDocument, workflow.signature?.signedDocument);
    }
  });

  test('test_sign_fake_workflow_property_never_signed_gets_the_fake_'
      'document', () {
    final Random random = seededRandom(95183);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      ).withName(randomText(random));

      final WorkflowSignature signed = signFakeWorkflow(
        workflow: workflow,
        pendingChange: null,
        signedBy: DeviceId(randomText(random)),
        signedAt: randomUtcMoment(random),
      );

      expect(signed.signedDocument, 'name: ${workflow.name}\n');
    }
  });

  test('test_sign_fake_workflow_property_keeps_signer_and_moment', () {
    final Random random = seededRandom(95184);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomMaybeSignedWorkflow(random, i);
      final DeviceId signer = DeviceId(randomText(random));
      final DateTime moment = randomUtcMoment(random);
      final WorkflowChange? change = random.nextBool()
          ? randomChangeFor(random, workflow.id)
          : null;

      final WorkflowSignature signed = signFakeWorkflow(
        workflow: workflow,
        pendingChange: change,
        signedBy: signer,
        signedAt: moment,
      );

      expect(signed.signedBy, signer);
      expect(signed.signedAt, moment);
      expect(signed.signature, isNotEmpty);
    }
  });
}
