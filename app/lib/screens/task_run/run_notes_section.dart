import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

const String runNotesTitle = 'Notes';

class RunNotesSection extends StatelessWidget {
  const RunNotesSection({required this.notes, super.key});

  final List<RunNote> notes;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: runNotesTitle,
      children: <Widget>[
        ResponsiveList.plain(
          rows: <ListRowData>[
            for (final RunNote note in notes)
              ListRowData(
                main: ListRowMain(title: note.text),
                end: Text(formatClockTime(note.at)),
              ),
          ],
        ),
      ],
    );
  }
}
