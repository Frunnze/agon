import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _dismissLabel = 'Close';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: _dismissLabel,
    barrierColor: AppColors.scrim,
    transitionDuration: AppDurations.enter,
    pageBuilder: (BuildContext dialogContext, Animation<double> _, _) =>
        AppDialogPlacement(child: builder(dialogContext)),
    transitionBuilder: _buildDialogEntrance,
  );
}

Widget _buildDialogEntrance(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<Offset> slide = Tween<Offset>(
    begin: const Offset(0, AppSpacing.space4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

  return FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: slide,
      child: child,
      builder: (BuildContext _, Widget? panel) =>
          Transform.translate(offset: slide.value, child: panel),
    ),
  );
}

class AppDialogPlacement extends StatelessWidget {
  const AppDialogPlacement({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (LayoutSize.of(context).isCompact) {
      return Align(alignment: Alignment.bottomCenter, child: child);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.dialogMaximumWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final String title;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final LayoutSize layoutSize = LayoutSize.of(context);
    final bool isCompact = layoutSize.isCompact;
    final double maximumHeight =
        MediaQuery.sizeOf(context).height * AppSizes.dialogMaximumHeightShare;
    const Radius corner = Radius.circular(AppRadii.panel);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: title,
      child: Material(
        color: AppColors.raised,
        borderRadius: isCompact
            ? const BorderRadius.only(topLeft: corner, topRight: corner)
            : const BorderRadius.all(corner),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maximumHeight,
            minWidth: double.infinity,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: DefaultTextStyle.merge(
              style: AppTextStyles.body,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaceVertically(<Widget>[
                  Text(title, style: AppTextStyles.heading),
                  ...content,
                  _buildActions(layoutSize),
                ], AppSpacing.space4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(LayoutSize layoutSize) {
    if (layoutSize.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaceVertically(
          actions.reversed.toList(),
          AppSpacing.space2,
        ),
      );
    }

    final Widget actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: spaceHorizontally(actions, AppSpacing.space2),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(fit: BoxFit.scaleDown, child: actionRow),
    );
  }
}

class DialogNote extends StatelessWidget {
  const DialogNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.smallMuted);
  }
}
