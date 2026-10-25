import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final bool showDrawerOnDesktop;
  final Widget? bottomNavigationBar;

  /// When false, no [AppBar] is built — use under a parent shell that already
  /// shows the title. [actions] are shown in a top row above [body].
  final bool useAppBar;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.showDrawerOnDesktop = false,
    this.bottomNavigationBar,
    this.useAppBar = true,
  });

  EdgeInsets _bodyPadding(BuildContext context, bool isMobile) {
    if (isMobile) {
      if (!useAppBar) {
        // Main workspace shell merges hub / nav inset into [MediaQuery.padding]; keep only
        // horizontal and top gutters so content can paint edge-to-edge above the backdrop.
        return const EdgeInsets.only(
          left: AppTheme.kSpacingMedium,
          right: AppTheme.kSpacingMedium,
          top: AppTheme.kSpacingMedium,
        );
      }
      return const EdgeInsets.all(AppTheme.kSpacingMedium);
    }
    // Shell workspace already shows the title; slimmer horizontal inset on web/desktop.
    if (!useAppBar) {
      return const EdgeInsets.only(
        left: AppTheme.kSpacingMedium,
        right: AppTheme.kSpacingMedium,
        top: AppTheme.kSpacingMedium,
      );
    }
    if (AppTheme.isDesktop(context)) {
      return const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingMedium,
        vertical: AppTheme.kSpacingLarge,
      );
    }
    return const EdgeInsets.all(AppTheme.kSpacingLarge);
  }

  Widget _bodyWithOptionalInlineActions(
    BuildContext context, {
    required bool isMobile,
  }) {
    final pad = _bodyPadding(context, isMobile);
    final actionWidgets = actions;
    if (!useAppBar && actionWidgets != null && actionWidgets.isNotEmpty) {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppTheme.kSpacingSmall,
                runSpacing: AppTheme.kSpacingSmall,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actionWidgets,
              ),
            ),
            const SizedBox(height: AppTheme.kSpacingSmall),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Padding(padding: pad, child: body);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    final isMobile = AppTheme.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.2;
    final adjustedDrawerWidth = drawerWidth.clamp(280.0, 400.0);

    if (isDesktop && !showDrawerOnDesktop) {
      return Scaffold(
        body: Row(
          children: [
            if (drawer != null)
              SizedBox(
                width: adjustedDrawerWidth,
                child: Drawer(
                  elevation: 0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: drawer,
                ),
              ),
            Expanded(
              child: Scaffold(
                appBar: useAppBar
                    ? AppBar(
                        title: Text(title),
                        actions: actions,
                        automaticallyImplyLeading: false,
                        elevation: 1,
                      )
                    : null,
                body: useAppBar
                    ? Padding(
                        padding: _bodyPadding(context, isMobile),
                        child: body,
                      )
                    : _bodyWithOptionalInlineActions(
                        context,
                        isMobile: isMobile,
                      ),
                floatingActionButton: floatingActionButton,
                bottomNavigationBar: bottomNavigationBar,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: useAppBar
          ? AppBar(title: Text(title), actions: actions, elevation: 1)
          : null,
      drawer: drawer != null && (isMobile || showDrawerOnDesktop)
          ? drawer
          : null,
      body: useAppBar
          ? Padding(padding: _bodyPadding(context, isMobile), child: body)
          : _bodyWithOptionalInlineActions(context, isMobile: isMobile),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
