import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/scope_cleanup.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';
import '../fakes/support/workspace_scope_inputs.dart';

const int _largestListedCount = 8;
const List<WorkspaceId> _workspacePool = <WorkspaceId>[
  WorkspaceId('workspace-acme'),
  WorkspaceId('workspace-personal'),
  WorkspaceId('Workspace-Acme'),
  WorkspaceId(''),
  WorkspaceId(' '),
  WorkspaceId('café'),
];

WorkspaceId _randomWorkspaceId(Random random) {
  if (random.nextInt(4) == 0) {
    return WorkspaceId(randomText(random));
  }
  return pickOne(random, _workspacePool);
}

List<WorkspaceId> _randomListedIds(Random random) {
  final int count = random.nextInt(_largestListedCount);
  return <WorkspaceId>[
    for (int i = 0; i < count; i += 1) _randomWorkspaceId(random),
  ];
}

Scope _randomOnlyScope(Random random) {
  return Scope(
    workspaces: OnlyWorkspaces(_randomListedIds(random)),
    projects: randomProjectScope(random),
  );
}

Scope _randomHostileScope(Random random) {
  if (random.nextInt(3) == 0) {
    return Scope(
      workspaces: const AllWorkspaces(),
      projects: randomProjectScope(random),
    );
  }
  return _randomOnlyScope(random);
}

List<WorkspaceId> _listedIdsOf(Scope scope) {
  final WorkspaceScope workspaces = scope.workspaces;
  if (workspaces is! OnlyWorkspaces) {
    throw StateError('expected a list of workspaces');
  }
  return workspaces.workspaces;
}

Set<WorkspaceId> _randomKnownIds(Random random) {
  return _randomListedIds(random).toSet();
}

String _encodeScope(Scope scope) {
  return jsonEncode(mapScopeToNode(scope).toJson());
}

void main() {
  test('test_forget_workspace_in_scope_property_removes_exactly_that_id', () {
    final Random random = seededRandom(71101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomHostileScope(random);
      final WorkspaceId forgotten = _randomWorkspaceId(random);

      final Scope after = forgetWorkspaceInScope(scope, forgotten);

      final Scope expected = predictScopeAfterForget(scope, forgotten);
      expect(_encodeScope(after), _encodeScope(expected));
    }
  });

  test('test_forget_workspace_in_scope_property_keeps_all_workspaces_and_'
      'projects', () {
    final Random random = seededRandom(71102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomHostileScope(random);
      final WorkspaceId forgotten = _randomWorkspaceId(random);

      final Scope after = forgetWorkspaceInScope(scope, forgotten);

      expect(after.projects, same(scope.projects));
      if (scope.workspaces is AllWorkspaces) {
        expect(after.workspaces, isA<AllWorkspaces>());
      }
    }
  });

  test('test_forget_workspace_in_scope_property_is_idempotent', () {
    final Random random = seededRandom(71103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomHostileScope(random);
      final WorkspaceId forgotten = _randomWorkspaceId(random);

      final Scope once = forgetWorkspaceInScope(scope, forgotten);
      final Scope twice = forgetWorkspaceInScope(once, forgotten);

      expect(_encodeScope(twice), _encodeScope(once));
    }
  });

  test('test_forget_workspace_in_scope_property_order_of_forgets_does_not_'
      'matter', () {
    final Random random = seededRandom(71104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomHostileScope(random);
      final WorkspaceId first = _randomWorkspaceId(random);
      final WorkspaceId second = _randomWorkspaceId(random);

      final Scope firstThenSecond = forgetWorkspaceInScope(
        forgetWorkspaceInScope(scope, first),
        second,
      );
      final Scope secondThenFirst = forgetWorkspaceInScope(
        forgetWorkspaceInScope(scope, second),
        first,
      );

      expect(_encodeScope(firstThenSecond), _encodeScope(secondThenFirst));
    }
  });

  test('test_without_workspace_property_keeps_the_others_in_order', () {
    final Random random = seededRandom(71105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomOnlyScope(random);
      final List<WorkspaceId> listed = _listedIdsOf(scope);
      final WorkspaceId forgotten = listed.isNotEmpty && random.nextBool()
          ? pickOne(random, listed)
          : _randomWorkspaceId(random);

      final List<WorkspaceId> kept = _listedIdsOf(
        forgetWorkspaceInScope(scope, forgotten),
      );

      final List<WorkspaceId> expected = <WorkspaceId>[
        for (final WorkspaceId listedId in listed)
          if (listedId != forgotten) listedId,
      ];
      expect(kept, orderedEquals(expected));
      expect(kept, isNot(contains(forgotten)));
    }
  });

  test('test_without_workspace_property_leaves_the_given_scope_alone', () {
    final Random random = seededRandom(71106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomOnlyScope(random);
      final List<WorkspaceId> listedBefore = List<WorkspaceId>.of(
        _listedIdsOf(scope),
      );
      final WorkspaceId forgotten = listedBefore.isEmpty
          ? _randomWorkspaceId(random)
          : pickOne(random, listedBefore);

      forgetWorkspaceInScope(scope, forgotten);

      expect(_listedIdsOf(scope), orderedEquals(listedBefore));
    }
  });

  test('test_without_workspace_property_result_cannot_be_changed', () {
    final Random random = seededRandom(71107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomOnlyScope(random);
      final WorkspaceId forgotten = _randomWorkspaceId(random);
      final List<WorkspaceId> kept = _listedIdsOf(
        forgetWorkspaceInScope(scope, forgotten),
      );

      expect(() => kept.add(forgotten), throwsUnsupportedError);
    }
  });

  test('test_is_seen_in_no_workspace_property_matches_the_model', () {
    final Random random = seededRandom(71108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope workspaces = _randomHostileScope(random).workspaces;
      final Set<WorkspaceId> known = _randomKnownIds(random);

      expect(
        isSeenInNoWorkspace(workspaces, known),
        isModelSeenInNoWorkspace(workspaces, known),
      );
    }
  });

  test('test_is_seen_in_no_workspace_property_all_workspaces_is_always_'
      'seen', () {
    final Random random = seededRandom(71109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<WorkspaceId> known = _randomKnownIds(random);

      expect(isSeenInNoWorkspace(const AllWorkspaces(), known), isFalse);
    }
  });

  test('test_is_seen_in_no_workspace_property_more_known_ids_never_hide', () {
    final Random random = seededRandom(71110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceScope workspaces = _randomHostileScope(random).workspaces;
      final Set<WorkspaceId> known = _randomKnownIds(random);
      final Set<WorkspaceId> moreKnown = <WorkspaceId>{
        ...known,
        ..._randomKnownIds(random),
      };

      final bool isUnseenWithMore = isSeenInNoWorkspace(workspaces, moreKnown);

      if (isUnseenWithMore) {
        expect(isSeenInNoWorkspace(workspaces, known), isTrue);
      }
    }
  });

  test('test_is_seen_in_no_workspace_property_empty_list_is_always_'
      'unseen', () {
    final Random random = seededRandom(71111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<WorkspaceId> known = _randomKnownIds(random);

      expect(
        isSeenInNoWorkspace(OnlyWorkspaces(const <WorkspaceId>[]), known),
        isTrue,
      );
    }
  });

  test('test_is_seen_in_no_workspace_property_ignores_the_forgotten_id', () {
    final Random random = seededRandom(71112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomHostileScope(random);
      final WorkspaceId forgotten = _randomWorkspaceId(random);
      final Set<WorkspaceId> remaining = _randomKnownIds(random);
      remaining.remove(forgotten);

      final Scope after = forgetWorkspaceInScope(scope, forgotten);

      expect(
        isSeenInNoWorkspace(after.workspaces, remaining),
        isSeenInNoWorkspace(scope.workspaces, remaining),
      );
    }
  });
}
