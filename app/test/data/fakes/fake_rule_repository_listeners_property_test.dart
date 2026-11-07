import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_scoped_rules.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _longestChangeSequence = 8;
const int _largestListenerCount = 4;

Future<void> _changeWorkspacesRandomly(
  Random random,
  WorkspaceRules workspaceRules,
) async {
  final int changeCount = random.nextInt(_longestChangeSequence);
  for (int step = 0; step < changeCount; step += 1) {
    final WorkspaceId target = pickOne(random, workspaceRules.workspaceIds);
    if (random.nextBool()) {
      await workspaceRules.workspaces.switchWorkspace(target);
    } else {
      await workspaceRules.workspaces.changeApprovalPolicy(
        workspaceId: target,
        approvalPolicy: pickOne(random, ApprovalPolicy.values),
      );
    }
  }
}

NotificationCounter _countWorkspaceNotifications(
  WorkspaceRules workspaceRules,
) {
  final NotificationCounter counter = NotificationCounter();
  workspaceRules.workspaces.addListener(counter.record);
  return counter;
}

NotificationCounter _countRuleNotifications(FakeRuleRepository rules) {
  final NotificationCounter counter = NotificationCounter();
  rules.addListener(counter.record);
  return counter;
}

Future<List<FlutterErrorDetails>> _collectReportedErrors(
  Future<void> Function() work,
) async {
  final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previousHandler = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await work();
  } finally {
    FlutterError.onError = previousHandler;
  }
  return reported;
}

final class _ListingRecorder {
  _ListingRecorder(this.rules);

  final FakeRuleRepository rules;
  List<String> latestListing = const <String>[];

  void record() {
    latestListing = describeStoredRules(rules.listRules());
  }
}

void main() {
  test('${_typePrefix}_constructor_property_forwards_every_workspace_'
      'notification', () async {
    final Random random = seededRandom(73101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final NotificationCounter workspaceNotifications =
          _countWorkspaceNotifications(workspaceRules);
      final NotificationCounter ruleNotifications = _countRuleNotifications(
        workspaceRules.rules,
      );

      await _changeWorkspacesRandomly(random, workspaceRules);

      expect(ruleNotifications.count, workspaceNotifications.count);
    }
  });

  test('${_typePrefix}_constructor_property_listeners_see_the_new_'
      'listing', () async {
    final Random random = seededRandom(73102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final _ListingRecorder recorder = _ListingRecorder(workspaceRules.rules);
      workspaceRules.rules.addListener(recorder.record);
      final WorkspaceId target = pickOne(random, workspaceRules.workspaceIds);

      await workspaceRules.workspaces.switchWorkspace(target);

      final List<String> expected = describeStoredRules(
        filterModelRulesFor(workspaceRules.seeded, target),
      );
      expect(recorder.latestListing, orderedEquals(expected));
    }
  });

  test('${_typePrefix}_constructor_property_forwards_to_every_rule_'
      'listener', () async {
    final Random random = seededRandom(73103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final NotificationCounter workspaceNotifications =
          _countWorkspaceNotifications(workspaceRules);
      final int listenerCount = 1 + random.nextInt(_largestListenerCount);
      final List<NotificationCounter> counters = <NotificationCounter>[
        for (int j = 0; j < listenerCount; j += 1)
          _countRuleNotifications(workspaceRules.rules),
      ];

      await _changeWorkspacesRandomly(random, workspaceRules);

      for (final NotificationCounter counter in counters) {
        expect(counter.count, workspaceNotifications.count);
      }
    }
  });

  test('${_typePrefix}_dispose_property_stops_forwarding_'
      'notifications', () async {
    final Random random = seededRandom(73104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final NotificationCounter ruleNotifications = _countRuleNotifications(
        workspaceRules.rules,
      );
      await _changeWorkspacesRandomly(random, workspaceRules);
      final int countBeforeDispose = ruleNotifications.count;

      workspaceRules.rules.dispose();
      final List<FlutterErrorDetails> reported = await _collectReportedErrors(
        () => _changeWorkspacesRandomly(random, workspaceRules),
      );

      expect(reported, isEmpty);
      expect(ruleNotifications.count, countBeforeDispose);
    }
  });

  test('${_typePrefix}_dispose_property_keeps_other_rule_repositories_'
      'listening', () async {
    final Random random = seededRandom(73105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final FakeRuleRepository sibling = FakeRuleRepository(
        rules: workspaceRules.seeded,
        clock: FixedClock(randomUtcMoment(random)),
        workspaceRepository: workspaceRules.workspaces,
      );
      final NotificationCounter siblingNotifications = _countRuleNotifications(
        sibling,
      );

      workspaceRules.rules.dispose();
      final NotificationCounter workspaceNotifications =
          _countWorkspaceNotifications(workspaceRules);
      final List<FlutterErrorDetails> reported = await _collectReportedErrors(
        () => _changeWorkspacesRandomly(random, workspaceRules),
      );

      expect(reported, isEmpty);
      expect(siblingNotifications.count, workspaceNotifications.count);
      sibling.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_leaves_the_workspaces_'
      'working', () async {
    final Random random = seededRandom(73106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceRules workspaceRules = seedWorkspaceRules(random);
      final NotificationCounter workspaceNotifications =
          _countWorkspaceNotifications(workspaceRules);
      final WorkspaceId target = pickOne(random, workspaceRules.workspaceIds);

      workspaceRules.rules.dispose();
      final List<FlutterErrorDetails> reported = await _collectReportedErrors(
        () => workspaceRules.workspaces.switchWorkspace(target),
      );

      expect(reported, isEmpty);
      expect(workspaceNotifications.count, 1);
      expect(workspaceRules.workspaces.currentWorkspace().id, target);
    }
  });
}
