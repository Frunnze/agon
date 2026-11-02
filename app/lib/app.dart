import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_shell.dart';
import 'package:agent_orchestration/theme/app_theme.dart';

class AgentOrchestrationApp extends StatelessWidget {
  const AgentOrchestrationApp({
    required this.dependencies,
    required this.navigation,
    required this.messengerKey,
    super.key,
  });

  final AppDependencies dependencies;
  final AppNavigation navigation;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: productName,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(dependencies: dependencies, navigation: navigation),
    );
  }
}
