import 'dart:math';

import 'simulated_catalog_node.dart';

typedef SimulatedRecord = Map<String, Object?>;

const String _identifierField = 'id';
const String _hexDigits = '0123456789abcdef';
const int _randomIdentifierLength = 8;

String readSimulatedIdentifier(SimulatedRecord record) {
  return record[_identifierField]! as String;
}

int compareSimulatedIdentifiers(
  SimulatedRecord first,
  SimulatedRecord second,
) {
  return readSimulatedIdentifier(first)
      .compareTo(readSimulatedIdentifier(second));
}

String randomRecordIdentifier(Random random, String kind) {
  final StringBuffer identifier = StringBuffer('$kind-');
  for (int i = 0; i < _randomIdentifierLength; i += 1) {
    identifier.write(_hexDigits[random.nextInt(_hexDigits.length)]);
  }
  return identifier.toString();
}

void giveRandomIdentifiers(
  Random random,
  List<SimulatedRecord> records, {
  required String kind,
}) {
  for (final SimulatedRecord record in records) {
    record[_identifierField] = randomRecordIdentifier(random, kind);
  }
}

bool isInIdentifierOrder(List<String> identifiers) {
  for (int i = 1; i < identifiers.length; i += 1) {
    final bool isAfterPrevious =
        identifiers[i - 1].compareTo(identifiers[i]) < 0;
    if (!isAfterPrevious) {
      return false;
    }
  }
  return true;
}

final class IdentifierOrderedCatalogNode {
  IdentifierOrderedCatalogNode(this.catalog);

  final SimulatedCatalogNode catalog;

  String answer(String inputJson) {
    catalog.workspaces.sort(compareSimulatedIdentifiers);
    catalog.projects.sort(compareSimulatedIdentifiers);
    catalog.skills.sort(compareSimulatedIdentifiers);
    catalog.rules.sort(compareSimulatedIdentifiers);
    return catalog.answer(inputJson);
  }
}
