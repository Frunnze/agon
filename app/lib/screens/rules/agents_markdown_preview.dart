import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/agents_markdown.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

const String _blankCodeLine = ' ';

List<CodeBlockLine> splitMarkdownLines(String markdown) {
  final List<String> lines = markdown.split('\n');
  if (lines.last.isEmpty) {
    lines.removeLast();
  }

  return <CodeBlockLine>[
    for (final String line in lines)
      CodeBlockLine(line.isEmpty ? _blankCodeLine : line),
  ];
}

class AgentsMarkdownPreview extends StatelessWidget {
  const AgentsMarkdownPreview({
    required this.rules,
    required this.workspaceId,
    required this.project,
    super.key,
  });

  final List<Rule> rules;
  final WorkspaceId workspaceId;
  final Project project;

  @override
  Widget build(BuildContext context) {
    final String markdown = renderAgentsMarkdown(
      rules: rules,
      workspaceId: workspaceId,
      projectId: project.id,
    );

    return PageSection(
      title: 'AGENTS.md for ${project.name}',
      children: <Widget>[
        if (markdown.isEmpty)
          Text('No rules apply to ${project.name} yet.')
        else
          Semantics(
            label: 'Generated AGENTS.md',
            child: CodeBlock(lines: splitMarkdownLines(markdown)),
          ),
        const MutedNote(
          "A project's own AGENTS.md is kept. These rules are added on top.",
        ),
      ],
    );
  }
}
