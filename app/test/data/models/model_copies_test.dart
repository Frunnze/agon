import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_with_decision_property_request_identity_kept', () {
    final Random random = seededRandom(7001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, galleryApprovals);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ApprovalRequest decided = request.withDecision(
        SignedDecision(
          decision: decision,
          decidedBy: GalleryDeviceIds.airLaptop,
          decidedAt: galleryNow,
          signature: const <int>[1],
        ),
      );

      expect(decided.id, request.id);
      expect(decided.action, same(request.action));
      expect(decided.decision?.decision, decision);
    }
  });

  test('test_with_messages_property_only_messages_change', () {
    final Random random = seededRandom(7002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Conversation conversation = pickOne(random, <Conversation>[
        galleryConversationAwaitingApproval,
        galleryConversationReconnecting,
        galleryConversationReplying,
      ]);
      final int keep = random.nextInt(conversation.messages.length + 1);
      final Conversation changed = conversation.withMessages(
        conversation.messages.take(keep).toList(),
      );

      expect(changed.messages.length, keep);
      expect(changed.link, conversation.link);
      expect(changed.agentActivity, conversation.agentActivity);
      expect(changed.messages.clear, throwsUnsupportedError);
    }
  });

  test('test_as_revoked_property_only_revocation_changes', () {
    final Random random = seededRandom(7003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final Device revoked = device.asRevoked();

      expect(revoked.revoked, isTrue);
      expect(revoked.workspaces, device.workspaces);
      expect(revoked.role, device.role);
    }
  });

  test('test_with_workspaces_property_replaces_membership', () {
    final Random random = seededRandom(7004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final List<WorkspaceId> workspaces = <WorkspaceId>[
        if (random.nextBool()) GalleryWorkspaceIds.acme,
        if (random.nextBool()) GalleryWorkspaceIds.personal,
      ];
      final Device moved = device.withWorkspaces(workspaces);

      expect(moved.workspaces, workspaces);
      expect(moved.revoked, device.revoked);
    }
  });

  test('test_as_enabled_property_rule_on_and_unchanged_otherwise', () {
    final Random random = seededRandom(7005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      expect(rule.asEnabled().enabled, isTrue);
      expect(rule.asEnabled().details, rule.details);
    }
  });

  test('test_as_disabled_property_rule_off_and_unchanged_otherwise', () {
    final Random random = seededRandom(7006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      expect(rule.asDisabled().enabled, isFalse);
      expect(rule.asDisabled().scope, same(rule.scope));
    }
  });

  test('test_with_progress_property_identity_and_branch_kept', () {
    final Random random = seededRandom(7007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, galleryRuns);
      final RunStatus status = pickOne(random, RunStatus.values);
      final Run changed = run.withProgress(
        nextStatus: status,
        nextSteps: run.steps.reversed.toList(),
        nextFinishedAt: null,
      );

      expect(changed.status, status);
      expect(changed.id, run.id);
      expect(changed.worktreeBranch, run.worktreeBranch);
      expect(changed.steps.first.name, run.steps.last.name);
    }
  });

  test('test_as_paused_property_stops_new_runs_only', () {
    final Random random = seededRandom(7008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners);
      expect(runner.asPaused().acceptingNewRuns, isFalse);
      expect(runner.asPaused().slotsBusy, runner.slotsBusy);
    }
  });

  test('test_as_accepting_new_runs_property_accepts_runs_only', () {
    final Random random = seededRandom(7009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = pickOne(random, galleryRunners).asPaused();
      expect(runner.asAcceptingNewRuns().acceptingNewRuns, isTrue);
      expect(runner.asAcceptingNewRuns().labels, runner.labels);
    }
    expect(gallerySkills.length, 4);
  });
}
