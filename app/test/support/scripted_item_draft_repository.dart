import 'dart:async';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';

final class ScriptedItemDraftRepository implements ItemDraftRepository {
  final List<ItemDraftRequest> requests = <ItemDraftRequest>[];
  final List<ItemDraftRequest> stoppedRequests = <ItemDraftRequest>[];
  final Map<ItemDraftRequest, StreamController<ItemDraftProgress>>
  _controllers = <ItemDraftRequest, StreamController<ItemDraftProgress>>{};

  ItemDraftRequest get latestRequest => requests.last;

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) {
    requests.add(request);
    _controllers[request] = StreamController<ItemDraftProgress>();
    return _requireController(request).stream;
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    final StreamController<ItemDraftProgress>? controller = _controllers
        .remove(request);
    if (controller == null) {
      throw StateError('No ${request.kind.name} is being drafted');
    }
    stoppedRequests.add(request);
    await controller.close();
  }

  void reportProgress(ItemDraftProgress progress) {
    _requireController(latestRequest).add(progress);
  }

  void failLatestDraft(Object problem) {
    _requireController(latestRequest).addError(problem);
  }

  StreamController<ItemDraftProgress> _requireController(
    ItemDraftRequest request,
  ) {
    final StreamController<ItemDraftProgress>? controller =
        _controllers[request];
    if (controller == null) {
      throw StateError('The ${request.kind.name} draft is not running');
    }
    return controller;
  }
}
