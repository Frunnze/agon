import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../../support/random_inputs.dart';

ItemDraftRequest randomItemDraftRequest(
  Random random, {
  required DraftKind kind,
}) {
  return ItemDraftRequest(
    kind: kind,
    wish: 'Wish ${randomText(random)}',
    startedFrom: random.nextBool() ? null : randomText(random),
    change: null,
  );
}

FakeItemDraftRepository buildItemDraftRepository(
  Map<DraftKind, ItemDraft> drafts, {
  required DeviceId drafterDeviceId,
}) {
  return FakeItemDraftRepository(
    drafts: drafts,
    drafterDeviceId: drafterDeviceId,
    stepDelay: Duration.zero,
  );
}

Future<List<ItemDraftProgress>> draftItemToTheEnd(
  FakeItemDraftRepository repository,
  ItemDraftRequest request,
) {
  return repository.draftItem(request).toList();
}
