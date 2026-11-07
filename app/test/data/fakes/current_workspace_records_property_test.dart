import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/current_workspace_records.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';

const int _largestRecordCount = 8;

typedef _ScopedRecord = ({String name, WorkspaceScope workspaces});

WorkspaceScope _readWorkspaces(_ScopedRecord record) => record.workspaces;

List<_ScopedRecord> _randomRecords(
  Random random,
  List<WorkspaceId> workspaceIds,
) {
  final int count = random.nextInt(_largestRecordCount);
  return <_ScopedRecord>[
    for (int index = 0; index < count; index += 1)
      (
        name: 'record-$index',
        workspaces: randomWorkspaceScopeOver(random, workspaceIds),
      ),
  ];
}

List<String> _namesOf(List<_ScopedRecord> records) {
  return <String>[for (final _ScopedRecord record in records) record.name];
}

void main() {
  test('test_list_records_in_current_workspace_property_keeps_exactly_the_'
      'records_usable_in_the_current_workspace', () async {
    final Random random = seededRandom(91201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final List<WorkspaceId> workspaceIds = listWorkspaceIds(
        seeded.workspaces,
      );
      final List<_ScopedRecord> records = _randomRecords(random, workspaceIds);
      final Workspace chosen = pickOne(random, seeded.workspaces);
      await seeded.repository.switchWorkspace(chosen.id);

      final List<_ScopedRecord> listed = listRecordsInCurrentWorkspace(
        records: records,
        workspaceRepository: seeded.repository,
        readWorkspaceScope: _readWorkspaces,
      );

      expect(_namesOf(listed), <String>[
        for (final _ScopedRecord record in records)
          if (isModelUsableInWorkspace(record.workspaces, chosen.id))
            record.name,
      ]);
    }
  });

  test('test_list_records_in_current_workspace_property_keeps_the_stored_'
      'order_and_never_invents_records', () {
    final Random random = seededRandom(91202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final List<_ScopedRecord> records = _randomRecords(
        random,
        listWorkspaceIds(seeded.workspaces),
      );

      final List<_ScopedRecord> listed = listRecordsInCurrentWorkspace(
        records: records,
        workspaceRepository: seeded.repository,
        readWorkspaceScope: _readWorkspaces,
      );

      int searchFrom = 0;
      for (final _ScopedRecord record in listed) {
        final int position = records.indexOf(record, searchFrom);
        expect(position, greaterThanOrEqualTo(searchFrom));
        searchFrom = position + 1;
      }
      if (records.isNotEmpty) {
        expect(() => listed.add(records.first), throwsUnsupportedError);
      }
    }
  });

  test('test_list_records_in_current_workspace_property_lists_every_'
      'record_seen_in_all_workspaces', () {
    final Random random = seededRandom(91203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final int count = random.nextInt(_largestRecordCount);
      final List<_ScopedRecord> records = <_ScopedRecord>[
        for (int index = 0; index < count; index += 1)
          (name: 'everywhere-$index', workspaces: const AllWorkspaces()),
      ];

      final List<_ScopedRecord> listed = listRecordsInCurrentWorkspace(
        records: records,
        workspaceRepository: seeded.repository,
        readWorkspaceScope: _readWorkspaces,
      );

      expect(_namesOf(listed), _namesOf(records));
    }
  });
}
