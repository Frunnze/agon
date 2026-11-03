import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/new_items/chosen_folders.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/drafting_notices.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/item_review_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_sources.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

class NewItemScreen extends StatefulWidget {
  const NewItemScreen({
    required this.kind,
    required this.startedFrom,
    required this.sources,
    required this.review,
    required this.formRoute,
    required this.navigation,
    super.key,
  });

  final DraftKind kind;
  final String? startedFrom;
  final NewItemSources sources;
  final DraftReview review;
  final AppRoute formRoute;
  final AppNavigation navigation;

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final TextEditingController _wishController = TextEditingController();
  StreamSubscription<ItemDraftProgress>? _subscription;
  ItemDraftRequest? _runningRequest;
  DraftRunning? _running;
  ItemDraft? _draft;
  List<RepositoryDraft> _chosenFolders = const <RepositoryDraft>[];
  String? _wishProblem;
  String? _draftProblem;
  String? _stopProblem;
  String? _approvalProblem;
  bool _isApproving = false;

  NewItemTexts get _texts => describeNewItem(widget.kind);

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _wishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NewItemSources sources = widget.sources;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        sources.runnerRepository,
        sources.deviceRepository,
      ]),
      builder: _buildPhase,
    );
  }

  Widget _buildPhase(BuildContext context, Widget? _) {
    final ItemDraftRequest? request = _runningRequest;
    if (request != null) {
      return _buildDrafting(request);
    }
    final ItemDraft? draft = _draft;
    if (draft != null) {
      return _buildReview(draft);
    }
    return _buildRequest();
  }

  Widget _buildRequest() {
    final bool hasOnlineRunner = widget.sources.runnerRepository
        .listRunners()
        .any((Runner runner) => runner.online);
    final Widget? notice = hasOnlineRunner
        ? null
        : NoRunnerNotice(onFillForm: _openForm);
    final FolderPicker? folderPicker = widget.sources.folderPicker;
    final Widget? folderChoice = folderPicker == null
        ? null
        : ChosenFolderField(
            folders: _chosenFolders,
            folderPicker: folderPicker,
            deviceRepository: widget.sources.deviceRepository,
            onChanged: _keepChosenFolders,
          );

    return ItemRequestView(
      texts: _texts,
      wishController: _wishController,
      wishProblem: _wishProblem,
      notice: notice,
      folderChoice: folderChoice,
      onDraft: _startFirstDraft,
      onBack: widget.navigation.closeRoute,
    );
  }

  Widget _buildDrafting(ItemDraftRequest request) {
    final String returnLabel = request.change == null
        ? backToWordsLabel
        : backToDraftLabel;

    return ItemDraftingView(
      texts: _texts,
      wish: request.wish,
      state: describeDraftingState(
        running: _running,
        draftProblem: _draftProblem,
        stopProblem: _stopProblem,
        returnLabel: returnLabel,
        deviceRepository: widget.sources.deviceRepository,
        navigation: widget.navigation,
      ),
      onStop: () => unawaited(_stopDrafting(afterStopping: _leaveDrafting)),
      onFillForm: _openForm,
      onReturn: _leaveDrafting,
      onLeave: () => unawaited(_leavePageWhileDrafting()),
    );
  }

  Widget _buildReview(ItemDraft draft) {
    final bool canApprove = draft.canBeApproved && !_isApproving;

    return ItemReviewView(
      texts: _texts,
      state: ReviewState(
        facts: widget.review.describeFacts(draft.item),
        problems: draft.problems,
        approvalProblem: _approvalProblem,
      ),
      onApprove: canApprove ? () => unawaited(_approve(draft)) : null,
      onCancel: widget.navigation.closeRoute,
      onAskForChanges: (String note) => _askForChanges(draft, note),
    );
  }

  void _keepChosenFolders(List<RepositoryDraft> folders) {
    setState(() => _chosenFolders = folders);
  }

  void _openForm() {
    widget.navigation.replaceRoute(widget.formRoute);
  }

  ItemDraftRequest _describeRequest(ItemDraftChange? change) {
    return ItemDraftRequest(
      kind: widget.kind,
      wish: _wishController.text.trim(),
      startedFrom: widget.startedFrom,
      change: change,
      chosenFolders: _chosenFolders,
    );
  }

  void _startFirstDraft() {
    final ItemDraftRequest request = _describeRequest(null);
    if (request.wish.isEmpty) {
      setState(() => _wishProblem = emptyWishProblem);
      return;
    }

    _startDrafting(request);
  }

  void _askForChanges(ItemDraft draft, String note) {
    final ItemDraftChange change = ItemDraftChange(
      draft: draft.item,
      note: note,
    );
    _startDrafting(_describeRequest(change));
  }

  void _startDrafting(ItemDraftRequest request) {
    setState(() {
      _runningRequest = request;
      _running = null;
      _wishProblem = null;
      _draftProblem = null;
      _stopProblem = null;
      _approvalProblem = null;
    });
    final Stream<ItemDraftProgress> drafting = widget
        .sources
        .itemDraftRepository
        .draftItem(request);
    _subscription = drafting.listen(_showProgress, onError: _showProblem);
  }

  void _showProgress(ItemDraftProgress progress) {
    switch (progress) {
      case DraftRunning():
        setState(() => _running = progress);
      case DraftFinished(:final ItemDraft draft):
        setState(() {
          _draft = draft;
          _runningRequest = null;
          _running = null;
        });
    }
  }

  void _showProblem(Object problem) {
    setState(() {
      _draftProblem =
          describeProblemForPeople(problem) ?? unexplainedDraftProblem;
    });
  }

  void _leaveDrafting() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    setState(() {
      _runningRequest = null;
      _running = null;
      _draftProblem = null;
      _stopProblem = null;
    });
  }

  Future<void> _leavePageWhileDrafting() async {
    if (_draftProblem != null) {
      widget.navigation.closeRoute();
      return;
    }
    await _stopDrafting(afterStopping: widget.navigation.closeRoute);
  }

  Future<void> _stopDrafting({required VoidCallback afterStopping}) async {
    final ItemDraftRequest? request = _runningRequest;
    if (request == null) {
      afterStopping();
      return;
    }

    try {
      await widget.sources.itemDraftRepository.stopDrafting(request);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() => _stopProblem = explanation);
      }
      return;
    }

    if (mounted) {
      afterStopping();
    }
  }

  Future<void> _approve(ItemDraft draft) async {
    setState(() {
      _isApproving = true;
      _approvalProblem = null;
    });

    try {
      await widget.review.approve(draft.item);
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() {
          _approvalProblem = explanation;
          _isApproving = false;
        });
      }
    }
  }
}
