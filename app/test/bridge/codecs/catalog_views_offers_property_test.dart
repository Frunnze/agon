import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/random_catalog_json.dart';
import '../support/wire_json_edits.dart';

const String _offersField = 'this_device_offers';

enum _OfferBreak { notAnObject, unknownPlace, missingPlace, notAList }

void main() {
  test('test_decode_offers_property_reads_offers_in_order', () {
    final Random random = seededRandom(49800);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> offersJson = randomListOf(
        random,
        randomPlaceOfferJson,
      );
      final JsonObject wireJson = replaceWireField(
        randomRunnersViewJson(random),
        _offersField,
        offersJson,
      );

      final RunnersView view = RunnersView.fromJson(wireJson);
      final List<PlaceOffer> offers = _readOffers(view);

      expect(offers.length, offersJson.length);
      for (int k = 0; k < offers.length; k += 1) {
        final JsonObject offerJson = decodeObject(offersJson[k]);
        expect(offers[k].place.wireName, offerJson['place']);
        expect(offers[k].problem, offerJson['problem']);
      }
    }
  });

  test('test_decode_offers_property_only_absent_offers_are_unknown', () {
    final Random random = seededRandom(49801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomRunnersViewJson(random);
      final JsonObject withoutOffers = removeWireField(wireJson, _offersField);
      final JsonObject nullOffers = replaceWireField(
        wireJson,
        _offersField,
        null,
      );
      final JsonObject emptyOffers = replaceWireField(
        wireJson,
        _offersField,
        <Object?>[],
      );

      expect(RunnersView.fromJson(withoutOffers).thisDeviceOffers, isNull);
      expect(RunnersView.fromJson(nullOffers).thisDeviceOffers, isNull);
      expect(RunnersView.fromJson(emptyOffers).thisDeviceOffers, isEmpty);
    }
  });

  test('test_decode_offers_property_rejects_malformed_offers', () {
    final Random random = seededRandom(49802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> offersJson = <Object?>[
        randomPlaceOfferJson(random),
        ...randomListOf(random, randomPlaceOfferJson),
      ];
      final Object? brokenOffers = _breakOffers(random, offersJson);
      final JsonObject wireJson = replaceWireField(
        randomRunnersViewJson(random),
        _offersField,
        brokenOffers,
      );

      expect(() => RunnersView.fromJson(wireJson), throwsFormatException);
    }
  });

  testListCopyProperties(
    const ListCopy<RunnersView, PlaceOffer>(
      testNamePrefix: 'test_freeze_offers_property_offers',
      seed: 49810,
      buildElement: _buildPlaceOffer,
      construct: _buildRunnersView,
      readList: _readOffers,
    ),
  );

  test('test_freeze_offers_property_unknown_offers_stay_unknown', () {
    final Random random = seededRandom(49820);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnersView view = _buildRunnersView(random, null);

      expect(view.thisDeviceOffers, isNull);
    }
  });

  test('test_encode_offers_property_unknown_offers_encode_as_null', () {
    final Random random = seededRandom(49830);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnersView view = _buildRunnersView(random, null);
      final JsonObject encoded = view.toJson();

      expect(encoded.containsKey(_offersField), isTrue);
      expect(encoded[_offersField], isNull);
    }
  });

  test('test_encode_offers_property_no_offers_encode_as_empty_list', () {
    final Random random = seededRandom(49831);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnersView view = _buildRunnersView(random, <PlaceOffer>[]);

      final Object? encodedOffers = view.toJson()[_offersField];

      expect(encodedOffers, isA<List<Object?>>());
      expect(encodedOffers, isEmpty);
    }
  });

  test('test_encode_offers_property_offers_encode_in_order', () {
    final Random random = seededRandom(49832);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> offers = <PlaceOffer>[
        for (final Object? offerJson in randomListOf(
          random,
          randomPlaceOfferJson,
        ))
          PlaceOffer.fromJson(offerJson),
      ];
      final RunnersView view = _buildRunnersView(random, offers);

      final Object? encodedOffers = view.toJson()[_offersField];

      expect(encodedOffers, equals(<Object?>[
        for (final PlaceOffer offer in offers) offer.toJson(),
      ]));
    }
  });
}

PlaceOffer _buildPlaceOffer(Random random) {
  return PlaceOffer.fromJson(randomPlaceOfferJson(random));
}

RunnersView _buildRunnersView(Random random, List<PlaceOffer>? offers) {
  final RunnersView decoded = RunnersView.fromJson(
    randomRunnersViewJson(random),
  );
  return RunnersView(
    summary: decoded.summary,
    summaryText: decoded.summaryText,
    runners: decoded.runners,
    thisDeviceProblem: decoded.thisDeviceProblem,
    thisDeviceSettings: decoded.thisDeviceSettings,
    thisDeviceOffers: offers,
  );
}

List<PlaceOffer> _readOffers(RunnersView view) {
  final List<PlaceOffer>? offers = view.thisDeviceOffers;
  if (offers == null) {
    throw StateError('the runners view lost its offers');
  }
  return offers;
}

Object? _breakOffers(Random random, List<Object?> offersJson) {
  final List<Object?> brokenOffers = List<Object?>.of(offersJson);
  final int index = random.nextInt(offersJson.length);
  final JsonObject offerJson = decodeObject(offersJson[index]);

  switch (pickOne(random, _OfferBreak.values)) {
    case _OfferBreak.notAnObject:
      brokenOffers[index] = offerJson['place'];
    case _OfferBreak.unknownPlace:
      brokenOffers[index] = replaceWireField(offerJson, 'place', 'anywhere');
    case _OfferBreak.missingPlace:
      brokenOffers[index] = removeWireField(offerJson, 'place');
    case _OfferBreak.notAList:
      return offerJson;
  }

  return brokenOffers;
}
