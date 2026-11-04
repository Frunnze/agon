import 'package:agent_orchestration/shell/app_navigation.dart';

sealed class AppWindowPage {
  const AppWindowPage();
}

final class StartingWindowPage extends AppWindowPage {
  const StartingWindowPage();
}

final class SectionWindowPage extends AppWindowPage {
  const SectionWindowPage(this.navigation);

  final AppNavigation navigation;
}

final class RunWindowPage extends AppWindowPage {
  const RunWindowPage(this.navigation);

  final AppNavigation navigation;
}
