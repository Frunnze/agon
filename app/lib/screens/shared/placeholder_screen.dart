import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      children: <Widget>[
        PageHeader(
          title: title,
          summary: const <TextSegment>[
            TextSegment('This screen arrives in a later release.'),
          ],
        ),
      ],
    );
  }
}
