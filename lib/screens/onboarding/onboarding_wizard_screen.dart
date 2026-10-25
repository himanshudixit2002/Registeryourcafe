import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingWizardScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  static const _steps = [
    _StepData(
      icon: Icons.waving_hand_outlined,
      title: 'Welcome to your workspace!',
      description:
          'Let\'s get your venue set up in a few quick steps. You can skip '
          'any step and come back later.',
      actionLabel: null,
    ),
    _StepData(
      icon: Icons.table_bar_outlined,
      title: 'Add your tables',
      description:
          'Set up your floor plan by adding tables. Go to the Tables screen '
          'from the bottom navigation to add your first tables.',
      actionLabel: 'I\'ll add tables later',
    ),
    _StepData(
      icon: Icons.restaurant_menu_outlined,
      title: 'Create menu items',
      description:
          'Add your food and beverage items to the cafe menu. This enables '
          'ordering from tables.',
      actionLabel: 'I\'ll add menu later',
    ),
    _StepData(
      icon: Icons.storefront_outlined,
      title: 'Configure public listing',
      description:
          'Make your venue discoverable! Go to Settings > Public discovery '
          'to enable your public listing, menu, and floor booking.',
      actionLabel: 'I\'ll do this later',
    ),
    _StepData(
      icon: Icons.person_add_outlined,
      title: 'Invite your staff',
      description:
          'Add team members so they can help manage your venue. Go to '
          'Settings > Staff & access to create staff accounts.',
      actionLabel: 'I\'ll invite later',
    ),
    _StepData(
      icon: Icons.check_circle_outline,
      title: 'You\'re all set!',
      description:
          'Your workspace is ready. You can always access these features '
          'from the Settings screen. Enjoy managing your venue!',
      actionLabel: null,
    ),
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    _nextStep();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop
                    ? AppTheme.kSpacingXLarge
                    : AppTheme.kSpacingMedium,
                vertical: AppTheme.kSpacingMedium,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                itemCount: _steps.length,
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop
                          ? AppTheme.kSpacingXLarge * 2
                          : AppTheme.kSpacingLarge,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          step.icon,
                          size: 80,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          step.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop
                    ? AppTheme.kSpacingXLarge
                    : AppTheme.kSpacingMedium,
                0,
                isDesktop
                    ? AppTheme.kSpacingXLarge
                    : AppTheme.kSpacingMedium,
                AppTheme.kSpacingLarge +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _nextStep,
                    child: Text(
                      _currentStep == _steps.length - 1
                          ? 'Get started'
                          : 'Continue',
                    ),
                  ),
                  if (_steps[_currentStep].actionLabel != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _skip,
                      child: Text(_steps[_currentStep].actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;

  const _StepData({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
  });
}
