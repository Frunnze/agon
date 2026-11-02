import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';

void main() {
  test('test_describe_agent_place_title_property_every_place_is_distinct', () {
    final Set<String> titles = <String>{
      for (final AgentPlace place in AgentPlace.values)
        describeAgentPlaceTitle(place),
    };

    expect(titles.length, AgentPlace.values.length);
    expect(describeAgentPlaceTitle(AgentPlace.container), 'In Docker');
    expect(
      describeAgentPlaceTitle(AgentPlace.localProcess),
      'On this computer',
    );
  });

  test('test_describe_agent_place_detail_property_every_place_explains', () {
    final Set<String> details = <String>{
      for (final AgentPlace place in AgentPlace.values)
        describeAgentPlaceDetail(place),
    };

    expect(details.length, AgentPlace.values.length);
    for (final String detail in details) {
      expect(detail, endsWith('.'));
    }
    expect(describeAgentPlaceDetail(AgentPlace.container), contains('Docker'));
  });
}
