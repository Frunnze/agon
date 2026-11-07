import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';

const AgentKind _fakeDrafterKind = AgentKind.claudeCode;

final class FakeItemDraftRepository implements ItemDraftRepository {
  FakeItemDraftRepository({
    required Map<DraftKind, ItemDraft> drafts,
    required DeviceId drafterDeviceId,
    required Duration stepDelay,
  }) : _drafts = Map<DraftKind, ItemDraft>.unmodifiable(drafts),
       _drafterDeviceId = drafterDeviceId,
       _stepDelay = stepDelay;

  final Map<DraftKind, ItemDraft> _drafts;
  final DeviceId _drafterDeviceId;
  final Duration _stepDelay;
  final Map<ItemDraftRequest, Object> _runningDrafts =
      <ItemDraftRequest, Object>{};

  @override
  Stream<ItemDraftProgress> draftItem(ItemDraftRequest request) async* {
    if (request.wish.trim().isEmpty) {
      throw ArgumentError.value(request.wish, 'wish', 'Say what you want');
    }
    final ItemDraft? draft = _drafts[request.kind];
    if (draft == null) {
      throw StateError('No ${request.kind.name} draft is prepared');
    }
    if (_runningDrafts.containsKey(request)) {
      throw StateError('This ${request.kind.name} is already being drafted');
    }

    final Object run = Object();
    _runningDrafts[request] = run;
    try {
      await Future<void>.delayed(_stepDelay);
      if (!_isStillRunning(request, run)) {
        return;
      }
      yield DraftRunning(
        drafterKind: _fakeDrafterKind,
        drafterDeviceId: _drafterDeviceId,
      );

      await Future<void>.delayed(_stepDelay);
      if (!_isStillRunning(request, run)) {
        return;
      }
      yield DraftFinished(draft);
    } finally {
      if (_isStillRunning(request, run)) {
        _runningDrafts.remove(request);
      }
    }
  }

  @override
  Future<void> stopDrafting(ItemDraftRequest request) async {
    final Object? stoppedRun = _runningDrafts.remove(request);
    if (stoppedRun == null) {
      throw StateError('No ${request.kind.name} is being drafted');
    }
  }

  bool _isStillRunning(ItemDraftRequest request, Object run) {
    return identical(_runningDrafts[request], run);
  }
}
