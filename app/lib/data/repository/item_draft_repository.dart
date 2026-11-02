import 'package:agent_orchestration/data/models/item_draft.dart';

abstract interface class ItemDraftRepository {
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request);

  Future<void> stopDrafting(ItemDraftRequest request);
}
