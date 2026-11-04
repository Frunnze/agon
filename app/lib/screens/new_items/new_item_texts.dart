import 'package:agent_orchestration/data/models/item_draft.dart';

const String newItemHint =
    'An agent fills in everything else. You check it, then approve it.';
const String draftingSummary = 'Drafting from your words';
const String startingDraftText = 'Starting the draft';
const String askedSectionTitle = 'You asked';
const String reviewSummary =
    'Check what the agent filled in. Change it here or ask the agent.';
const String changeHint =
    'The agent drafts it again from what is on screen and your note.';
const String changeFieldLabel = 'What should the agent change?';
const String draftProblemsTitle = 'The agent could not fill in everything';
const String draftProblemsNote =
    'Each line names the field. Fix it here, or ask the agent below.';
const String approveLabel = 'Approve';
const String cancelReviewLabel = 'Cancel';
const String sendChangeLabel = 'Send';
const String stopDraftingLabel = 'Stop drafting';
const String fillInFormLabel = 'Fill in the form';
const String emptyWishProblem = 'Write what you want first.';
const String backToWordsLabel = 'Back to your words';
const String backToDraftLabel = 'Back to the draft';
const String approvalFailedTitle = 'It was not created';
const String unexplainedDraftProblem =
    'The drafting agent stopped without saying why. Try again.';
const String noRunnerTitle = 'No runner is online';
const String noRunnerText =
    'An agent drafts on a runner. The draft waits until one comes online, '
    'or you can fill in the form yourself.';

final class NewItemTexts {
  const NewItemTexts({
    required this.kindName,
    required this.sectionLabel,
    required this.question,
    required this.changeExample,
  });

  final String kindName;
  final String sectionLabel;
  final String question;
  final String changeExample;

  String get pageTitle => 'New $kindName';

  String get draftLabel => 'Draft $kindName';
}

NewItemTexts describeNewItem(DraftKind kind) {
  return switch (kind) {
    DraftKind.task => const NewItemTexts(
      kindName: 'task',
      sectionLabel: 'Tasks',
      question: 'What should be done?',
      changeExample: 'For example: ask before pushing',
    ),
    DraftKind.job => const NewItemTexts(
      kindName: 'job',
      sectionLabel: 'Jobs',
      question: 'What should repeat, and how often?',
      changeExample: 'For example: on Fridays instead',
    ),
    DraftKind.project => const NewItemTexts(
      kindName: 'project',
      sectionLabel: 'Projects',
      question: 'What is this project, and where is its code?',
      changeExample: 'For example: read only',
    ),
    DraftKind.skill => const NewItemTexts(
      kindName: 'skill',
      sectionLabel: 'Skills',
      question: 'What should agents know or do?',
      changeExample: 'For example: only when chosen',
    ),
    DraftKind.rule => const NewItemTexts(
      kindName: 'rule',
      sectionLabel: 'Rules',
      question: 'What must every agent follow?',
      changeExample: 'For example: only in one project',
    ),
  };
}
