import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed/identifier_order.dart';

import '../../support/random_inputs.dart';
import 'support/identifier_ordered_records.dart';

typedef _Listed = ({String identifier, String version});

const int _largestListingLength = 9;
const List<String> _hostileIdentifiers = <String>[
  '',
  ' ',
  'a',
  'ab',
  'a-b',
  'A',
  'z',
  'café',
  'Ünïcødé',
  '10',
  '9',
  'rule-10',
  'rule-9',
];

String _identifyListed(_Listed listed) => listed.identifier;

String _randomIdentifier(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _hostileIdentifiers);
  }
  return randomText(random);
}

List<_Listed> _randomSortedListing(Random random) {
  final Set<String> identifiers = <String>{};
  final int length = random.nextInt(_largestListingLength);
  for (int i = 0; i < length; i += 1) {
    identifiers.add(_randomIdentifier(random));
  }
  final List<String> sorted = identifiers.toList();
  sorted.sort();
  return <_Listed>[
    for (final String identifier in sorted)
      (identifier: identifier, version: randomText(random)),
  ];
}

_Listed _randomRecord(Random random, List<_Listed> listing) {
  final bool reusesListedIdentifier = listing.isNotEmpty && random.nextBool();
  final String identifier = reusesListedIdentifier
      ? pickOne(random, listing).identifier
      : _randomIdentifier(random);
  return (identifier: identifier, version: 'new ${randomText(random)}');
}

List<_Listed> _place(List<_Listed> listing, _Listed record) {
  return placeInIdentifierOrder(
    listing,
    record: record,
    identify: _identifyListed,
  );
}

List<String> _listIdentifiers(List<_Listed> listing) {
  return <String>[for (final _Listed listed in listing) listed.identifier];
}

int _compareListed(_Listed first, _Listed second) {
  return first.identifier.compareTo(second.identifier);
}

List<_Listed> _predictPlacement(List<_Listed> listing, _Listed record) {
  final List<_Listed> predicted = <_Listed>[
    for (final _Listed listed in listing)
      if (listed.identifier != record.identifier) listed,
    record,
  ];
  predicted.sort(_compareListed);
  return predicted;
}

void main() {
  test('test_place_in_identifier_order_property_matches_sorting_by_id', () {
    final Random random = seededRandom(81401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomSortedListing(random);
      final _Listed record = _randomRecord(random, listing);

      expect(_place(listing, record), _predictPlacement(listing, record));
    }
  });

  test('test_place_in_identifier_order_property_sorted_stays_sorted', () {
    final Random random = seededRandom(81402);
    for (int i = 0; i < propertyIterations; i += 1) {
      List<_Listed> listing = const <_Listed>[];
      final int placementCount = random.nextInt(_largestListingLength);

      for (int j = 0; j < placementCount; j += 1) {
        listing = _place(listing, _randomRecord(random, listing));

        expect(isInIdentifierOrder(_listIdentifiers(listing)), isTrue);
      }
    }
  });

  test(
    'test_place_in_identifier_order_property_listed_record_keeps_place',
    () {
      final Random random = seededRandom(81403);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<_Listed> listing = _randomSortedListing(random);
        listing.shuffle(random);
        if (listing.isEmpty) {
          continue;
        }
        final _Listed previous = pickOne(random, listing);
        final _Listed record = (
          identifier: previous.identifier,
          version: 'changed ${randomText(random)}',
        );

        final List<_Listed> placed = _place(listing, record);

        expect(placed.length, listing.length);
        expect(placed.indexOf(record), listing.indexOf(previous));
      }
    },
  );

  test('test_place_in_identifier_order_property_placing_twice_is_once', () {
    final Random random = seededRandom(81404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomSortedListing(random);
      final _Listed record = _randomRecord(random, listing);

      final List<_Listed> placedOnce = _place(listing, record);

      expect(_place(placedOnce, record), placedOnce);
    }
  });

  test('test_place_in_identifier_order_property_given_listing_is_kept', () {
    final Random random = seededRandom(81405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomSortedListing(random);
      final List<_Listed> listingBefore = List<_Listed>.of(listing);
      final _Listed record = _randomRecord(random, listing);

      final List<_Listed> placed = _place(listing, record);

      expect(listing, listingBefore);
      expect(() => placed.add(record), throwsUnsupportedError);
    }
  });
}
