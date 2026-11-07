import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/record_not_found.dart';

Matcher throwsMissingRecord(String kind, String identifier) {
  return throwsA(
    isA<RecordNotFound>()
        .having((RecordNotFound error) => error.kind, 'kind', kind)
        .having(
          (RecordNotFound error) => error.identifier,
          'identifier',
          identifier,
        ),
  );
}
