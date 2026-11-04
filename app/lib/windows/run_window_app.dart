import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/product_name.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/apply_layout_density.dart';
import 'package:agent_orchestration/windows/native_windows.dart';
import 'package:agent_orchestration/windows/run_window_screen.dart';

class RunWindowApp extends StatelessWidget {
  const RunWindowApp({
    required this.navigation,
    required this.dependencies,
    required this.onTopSwitch,
    required this.messengerKey,
    super.key,
  });

  final AppNavigation navigation;
  final AppDependencies dependencies;
  final OnTopSwitch onTopSwitch;
  final MessengerKey messengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: productName,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: applyLayoutDensity,
      home: Scaffold(
        body: SafeArea(
          child: RunWindowScreen(
            navigation: navigation,
            dependencies: dependencies,
            onTopSwitch: onTopSwitch,
          ),
        ),
      ),
    );
  }
}
