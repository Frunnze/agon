import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const int _wishMinimumLines = 5;
const int _wishMaximumLines = 12;

class ItemRequestView extends StatelessWidget {
  const ItemRequestView({
    required this.texts,
    required this.wishController,
    required this.wishProblem,
    required this.notice,
    required this.folderChoice,
    required this.onDraft,
    required this.onBack,
    super.key,
  });

  final NewItemTexts texts;
  final TextEditingController wishController;
  final String? wishProblem;
  final Widget? notice;
  final Widget? folderChoice;
  final VoidCallback onDraft;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Widget? shownNotice = notice;
    final Widget? shownFolderChoice = folderChoice;

    return AppPage(
      children: <Widget>[
        PageHeader(
          title: texts.pageTitle,
          backLink: BackLink(label: texts.sectionLabel, onPressed: onBack),
        ),
        ?shownNotice,
        FormColumn(
          children: <Widget>[
            FormFieldBlock(
              label: texts.question,
              hint: newItemHint,
              children: <Widget>[
                TextField(
                  controller: wishController,
                  minLines: _wishMinimumLines,
                  maxLines: _wishMaximumLines,
                  decoration: InputDecoration(
                    contentPadding: multiLineFieldPadding,
                    errorText: wishProblem,
                  ),
                ),
                ?shownFolderChoice,
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.primary(
                label: texts.draftLabel,
                icon: AppIconKind.draft,
                onPressed: onDraft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
