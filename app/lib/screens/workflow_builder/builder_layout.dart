import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const double _topShareOfPage = 0.5;
const double _sheetShareOfBuilder = 0.6;
const double _sidePanelWidth = 320;

class BuilderPageLayout extends StatelessWidget {
  const BuilderPageLayout({
    required this.top,
    required this.builder,
    super.key,
  });

  final List<Widget> top;
  final Widget builder;

  @override
  Widget build(BuildContext context) {
    final LayoutSize layoutSize = LayoutSize.of(context);
    final double gap = pageGapFor(layoutSize);

    return Padding(
      padding: pagePaddingFor(layoutSize),
      child: LayoutBuilder(
        builder: (BuildContext _, BoxConstraints limits) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: limits.maxHeight * _topShareOfPage,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: spaceVertically(top, gap),
                ),
              ),
            ),
            SizedBox(height: gap),
            Expanded(child: builder),
          ],
        ),
      ),
    );
  }
}

class BuilderFrame extends StatelessWidget {
  const BuilderFrame({required this.canvas, required this.panel, super.key});

  final Widget canvas;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    final Widget? panelContent = panel;
    if (panelContent == null) {
      return canvas;
    }

    if (LayoutSize.of(context).isLarge) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: canvas),
          const SizedBox(width: AppSpacing.space5),
          Container(
            width: _sidePanelWidth,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.line)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: AppSpacing.space5),
              child: panelContent,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints limits) => Stack(
        children: <Widget>[
          Positioned.fill(child: canvas),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: limits.maxHeight * _sheetShareOfBuilder,
              ),
              decoration: const BoxDecoration(
                color: AppColors.raised,
                border: Border(top: BorderSide(color: AppColors.line)),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadii.panel),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space5),
                child: panelContent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
