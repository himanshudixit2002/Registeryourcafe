import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer_feedback.dart';
import '../../providers/feedback_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class SubmitFeedbackScreen extends ConsumerStatefulWidget {
  final String? customerName;
  final String? customerId;
  final String? sessionId;

  const SubmitFeedbackScreen({
    super.key,
    this.customerName,
    this.customerId,
    this.sessionId,
  });

  @override
  ConsumerState<SubmitFeedbackScreen> createState() =>
      _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState
    extends ConsumerState<SubmitFeedbackScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      context.showErrorSnackbar('Please select a rating');
      return;
    }
    setState(() => _saving = true);
    try {
      final feedback = CustomerFeedback(
        id: '',
        customerId: widget.customerId,
        customerName: widget.customerName ?? 'Guest',
        rating: _rating,
        comment: _commentController.text.trim(),
        sessionId: widget.sessionId,
        createdAt: DateTime.now(),
      );
      await ref
          .read(feedbackServiceProvider)
          ?.submitFeedback(feedback);
      if (mounted) {
        context.showSuccessSnackbar('Thank you for your feedback!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your experience')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          AppTheme.isDesktop(context)
              ? AppTheme.kSpacingXLarge
              : AppTheme.kSpacingMedium,
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'How was your visit?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 48,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Tell us more (optional)...',
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 2,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5),
                      )
                    : const Text('Submit feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
