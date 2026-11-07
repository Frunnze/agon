import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/workspace_listing.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_scope_inputs.dart';
import 'support/identifier_ordered_records.dart';

typedef _Listed = ({String identifier, String version});

const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  WorkspaceId('workspace-home'),
  WorkspaceId('workspace-lab'),
];
const int _largestPlacementCount = 10;
const int _identifierSpan = 40;

String _identifyListed(_Listed listed) => listed.identifier;

_Listed _randomRecord(Random random) {
  return (
    identifier: 'record-${random.nextInt(_identifierSpan)}',
    version: randomText(random),
  );
}

List<String> _listIdentifiers(List<_Listed> listing) {
  return <String>[for (final _Listed listed in listing) listed.identifier];
}

List<_Listed> _place(
  List<_Listed> listing, {
  required _Listed record,
  required WorkspaceScope recordWorkspaces,
}) {
  return placeInWorkspaceListing(
    listing,
    record: record,
    recordWorkspaces: recordWorkspaces,
    listedWorkspaceId: _workspaceIds.first,
    identify: _identifyListed,
  );
}

List<_Listed> _placeRandomRecords(Random random) {
  List<_Listed> listing = const <_Listed>[];
  final int placementCount = random.nextInt(_largestPlacementCount);
  for (int i = 0; i < placementCount; i += 1) {
    listing = _place(
      listing,
      record: _randomRecord(random),
      recordWorkspaces: randomWorkspaceScopeOver(random, _workspaceIds),
    );
  }
  return listing;
}

void main() {
  test('test_place_in_workspace_listing_property_listing_stays_in_id_'
      'order', () {
    final Random random = seededRandom(81501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _placeRandomRecords(random);

      expect(isInIdentifierOrder(_listIdentifiers(listing)), isTrue);
    }
  });

  test('test_place_in_workspace_listing_property_listed_record_lands_after_'
      'every_smaller_id', () {
    final Random random = seededRandom(81502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _placeRandomRecords(random);
      final _Listed record = _randomRecord(random);

      final List<_Listed> placed = _place(
        listing,
        record: record,
        recordWorkspaces: const AllWorkspaces(),
      );

      final int position = placed.indexOf(record);
      for (int j = 0; j < placed.length; j += 1) {
        final int order = placed[j].identifier.compareTo(record.identifier);
        expect(order < 0, j < position);
      }
    }
  });

  test('test_place_in_workspace_listing_property_out_of_scope_record_leaves_'
      'the_rest_in_order', () {
    final Random random = seededRandom(81503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _placeRandomRecords(random);
      final _Listed record = listing.isNotEmpty && random.nextBool()
          ? pickOne(random, listing)
          : _randomRecord(random);
      final WorkspaceScope elsewhere = OnlyWorkspaces(<WorkspaceId>[
        _workspaceIds.last,
      ]);

      final List<_Listed> placed = _place(
        listing,
        record: record,
        recordWorkspaces: elsewhere,
      );

      expect(includesWorkspace(elsewhere, _workspaceIds.first), isFalse);
      expect(_listIdentifiers(placed), <String>[
        for (final _Listed listed in listing)
          if (listed.identifier != record.identifier) listed.identifier,
      ]);
    }
  });
}
