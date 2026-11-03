import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';

AgentPlace mapAgentPlaceFromNode(node.AgentPlace place) {
  return switch (place) {
    node.AgentPlace.container => AgentPlace.container,
    node.AgentPlace.localProcess => AgentPlace.localProcess,
  };
}

node.AgentPlace mapAgentPlaceToNode(AgentPlace place) {
  return switch (place) {
    AgentPlace.container => node.AgentPlace.container,
    AgentPlace.localProcess => node.AgentPlace.localProcess,
  };
}

List<AgentPlace> mapAgentPlacesFromNode(List<node.AgentPlace> places) {
  return List<AgentPlace>.unmodifiable(<AgentPlace>[
    for (final node.AgentPlace place in places) mapAgentPlaceFromNode(place),
  ]);
}

List<PlaceOffer> mapPlaceOffersFromNode(List<node.PlaceOffer> offers) {
  return List<PlaceOffer>.unmodifiable(<PlaceOffer>[
    for (final node.PlaceOffer offer in offers)
      PlaceOffer(
        place: mapAgentPlaceFromNode(offer.place),
        problem: offer.problem,
      ),
  ]);
}
