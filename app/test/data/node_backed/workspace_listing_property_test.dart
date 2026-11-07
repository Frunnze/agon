import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/workspace_listing.dart';
import 'package:agent_orchestration/data/rules/scope_rules.dart';

import '../../support/random_inputs.dart';

typedef _ListedRecord = ({int identifier, String version});

const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  WorkspaceId('workspace-home'),
  WorkspaceId('workspace-lab'),
  WorkspaceId('workspace-attic'),
];
const int _largestListingLength = 8;
const int _identifierSpan = 12;

WorkspaceScope _randomWorkspaces(Random random) {
  if (random.nextInt(3) == 0) {
    return const AllWorkspaces();
  }
  final List<WorkspaceId> chosen = <WorkspaceId>[];
  for (final WorkspaceId workspaceId in _workspaceIds) {
    if (random.nextBool()) {
      chosen.add(workspaceId);
    }
  }
  return OnlyWorkspaces(chosen);
}

List<_ListedRecord> _randomListing(Random random, {required int leastLength}) {
  final int length =
      leastLength + random.nextInt(_largestListingLength - leastLength);
  final List<int> identifiers = <int>[
    for (int i = 0; i < _identifierSpan; i += 1) i,
  ];
  identifiers.shuffle(random);
  final List<_ListedRecord> listing = <_ListedRecord>[];
  for (int i = 0; i < length; i += 1) {
    listing.add((identifier: identifiers[i], version: randomText(random)));
  }
  return listing;
}

_ListedRecord _randomRecord(Random random) {
  return (
    identifier: random.nextInt(_identifierSpan),
    version: 'new ${randomText(random)}',
  );
}

String _identifyListedRecord(_ListedRecord listed) => '${listed.identifier}';

List<_ListedRecord> _placeRecord(
  List<_ListedRecord> listing, {
  required _ListedRecord record,
  required WorkspaceScope recordWorkspaces,
  required WorkspaceId listedWorkspaceId,
}) {
  return placeInWorkspaceListing(
    listing,
    record: record,
    recordWorkspaces: recordWorkspaces,
    listedWorkspaceId: listedWorkspaceId,
    identify: _identifyListedRecord,
  );
}

List<_ListedRecord> _withoutIdentifier(
  List<_ListedRecord> listing,
  int identifier,
) {
  return <_ListedRecord>[
    for (final _ListedRecord listed in listing)
      if (listed.identifier != identifier) listed,
  ];
}

void main() {
  test('test_place_in_workspace_listing_property_listed_only_when_its_'
      'scope_includes_the_workspace', () {
    final Random random = seededRandom(71401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ListedRecord record = _randomRecord(random);
      final WorkspaceScope recordWorkspaces = _randomWorkspaces(random);
      final WorkspaceId listedWorkspaceId = pickOne(random, _workspaceIds);

      final List<_ListedRecord> placed = _placeRecord(
        _randomListing(random, leastLength: 0),
        record: record,
        recordWorkspaces: recordWorkspaces,
        listedWorkspaceId: listedWorkspaceId,
      );

      final bool isIncluded = includesWorkspace(
        recordWorkspaces,
        listedWorkspaceId,
      );
      final int matchCount = placed
          .where(
            (_ListedRecord listed) => listed.identifier == record.identifier,
          )
          .length;
      expect(matchCount, isIncluded ? 1 : 0);
      expect(placed.contains(record), isIncluded);
    }
  });

  test('test_place_in_workspace_listing_property_other_records_keep_'
      'their_order', () {
    final Random random = seededRandom(71402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_ListedRecord> listing = _randomListing(
        random,
        leastLength: 0,
      );
      final _ListedRecord record = _randomRecord(random);

      final List<_ListedRecord> placed = _placeRecord(
        listing,
        record: record,
        recordWorkspaces: _randomWorkspaces(random),
        listedWorkspaceId: pickOne(random, _workspaceIds),
      );

      expect(
        _withoutIdentifier(placed, record.identifier),
        _withoutIdentifier(listing, record.identifier),
      );
    }
  });

  test('test_place_in_workspace_listing_property_placing_twice_changes_'
      'nothing_more', () {
    final Random random = seededRandom(71403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ListedRecord record = _randomRecord(random);
      final WorkspaceScope recordWorkspaces = _randomWorkspaces(random);
      final WorkspaceId listedWorkspaceId = pickOne(random, _workspaceIds);

      final List<_ListedRecord> placedOnce = _placeRecord(
        _randomListing(random, leastLength: 0),
        record: record,
        recordWorkspaces: recordWorkspaces,
        listedWorkspaceId: listedWorkspaceId,
      );
      final List<_ListedRecord> placedTwice = _placeRecord(
        placedOnce,
        record: record,
        recordWorkspaces: recordWorkspaces,
        listedWorkspaceId: listedWorkspaceId,
      );

      expect(placedTwice, placedOnce);
    }
  });

  test('test_place_in_workspace_listing_property_a_listed_record_keeps_'
      'its_place', () {
    final Random random = seededRandom(71404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_ListedRecord> listing = _randomListing(
        random,
        leastLength: 1,
      );
      final _ListedRecord previous = pickOne(random, listing);
      final _ListedRecord record = (
        identifier: previous.identifier,
        version: 'changed ${randomText(random)}',
      );
      final WorkspaceId listedWorkspaceId = pickOne(random, _workspaceIds);

      final List<_ListedRecord> placed = _placeRecord(
        listing,
        record: record,
        recordWorkspaces: OnlyWorkspaces(<WorkspaceId>[listedWorkspaceId]),
        listedWorkspaceId: listedWorkspaceId,
      );

      expect(placed.length, listing.length);
      expect(placed.indexOf(record), listing.indexOf(previous));
    }
  });

  test('test_place_in_workspace_listing_property_never_changes_the_given_'
      'listing', () {
    final Random random = seededRandom(71405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_ListedRecord> listing = _randomListing(
        random,
        leastLength: 0,
      );
      final List<_ListedRecord> listingBefore = List<_ListedRecord>.of(
        listing,
      );

      final List<_ListedRecord> placed = _placeRecord(
        listing,
        record: _randomRecord(random),
        recordWorkspaces: _randomWorkspaces(random),
        listedWorkspaceId: pickOne(random, _workspaceIds),
      );

      expect(listing, listingBefore);
      expect(() => placed.add(_randomRecord(random)), throwsUnsupportedError);
    }
  });
}
