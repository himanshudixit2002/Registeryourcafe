import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SASupportScreen extends ConsumerStatefulWidget {
  const SASupportScreen({super.key});

  @override
  ConsumerState<SASupportScreen> createState() => _SASupportScreenState();
}

class _SASupportScreenState extends ConsumerState<SASupportScreen> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(supportTicketsProvider),
          ),
        ],
      ),
      body: ticketsAsync.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No support tickets', style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Tickets submitted by cafes will appear here', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          final open = tickets.where((t) => (t.data()['status'] ?? 'open') == 'open').length;
          final inProgress = tickets.where((t) => t.data()['status'] == 'inProgress').length;
          final resolved = tickets.where((t) => t.data()['status'] == 'resolved').length;

          final filtered = tickets.where((t) {
            final d = t.data();
            final matchesStatus = _statusFilter == 'all' || (d['status'] ?? 'open') == _statusFilter;
            if (!matchesStatus) return false;
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            final subject = (d['subject'] as String? ?? '').toLowerCase();
            final message = (d['message'] as String? ?? '').toLowerCase();
            final companyId = (d['companyId'] as String? ?? '').toLowerCase();
            return subject.contains(q) || message.contains(q) || companyId.contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.kSpacingMedium,
                  AppTheme.kSpacingSmall,
                  AppTheme.kSpacingMedium,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(child: _StatChip(label: 'Open', count: open, color: AppTheme.warningColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'In Progress', count: inProgress, color: AppTheme.infoColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'Resolved', count: resolved, color: AppTheme.successColor)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.kSpacingMedium,
                  AppTheme.kSpacingSmall,
                  AppTheme.kSpacingMedium,
                  AppTheme.kSpacingSmall,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by subject, message, company...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: Row(
                  children: [
                    for (final entry in {'all': 'All', 'open': 'Open', 'inProgress': 'In Progress', 'resolved': 'Resolved', 'closed': 'Closed'}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (_) => setState(() => _statusFilter = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No tickets match your filters',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: AppTheme.getScreenPadding(context),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => FadeInWidget(
                          delay: Duration(milliseconds: 50 * index),
                          child: _TicketCard(doc: filtered[index]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Error loading tickets', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(supportTicketsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        children: [
          AnimatedCountUp(
            endValue: count.toDouble(),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _TicketCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = doc.data();
    final subject = data['subject'] as String? ?? 'No subject';
    final message = data['message'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final category = data['category'] as String? ?? '';
    final createdAt = data['createdAt'];
    final companyId = data['companyId'] as String? ?? '';

    String dateStr = '';
    if (createdAt is Timestamp) {
      dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
    }

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'open':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.circle_outlined;
      case 'inProgress':
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.pending;
      case 'resolved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
      case 'closed':
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.cancel;
      default:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }

    return AppCard(
      onTap: () => _showTicketDetail(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(subject, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(label: status.toUpperCase(), color: statusColor),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (category.isNotEmpty) ...[
                Chip(
                  label: Text(category, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
              ],
              if (companyId.isNotEmpty)
                Expanded(
                  child: Text(
                    'Company: $companyId',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _showTicketDetail(BuildContext context, WidgetRef ref) {
    final data = doc.data();
    final subject = data['subject'] as String? ?? 'No subject';
    final message = data['message'] as String? ?? 'No message';
    final status = data['status'] as String? ?? 'open';
    final companyId = data['companyId'] as String? ?? '';
    final replies = data['replies'] as List<dynamic>? ?? [];
    final replyController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(subject, style: Theme.of(context).textTheme.titleLarge),
              if (companyId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Company: $companyId', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              if (replies.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Replies', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final reply in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.reply, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                (reply as Map)['authorEmail'] as String? ?? 'Unknown',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(reply['message'] as String? ?? '', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text('Add Reply', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: replyController,
                decoration: const InputDecoration(
                  hintText: 'Type your reply...',
                  prefixIcon: Icon(Icons.reply),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = replyController.text.trim();
                    if (text.isEmpty) return;
                    try {
                      final email = FirebaseAuth.instance.currentUser?.email ?? '';
                      await ref.read(superAdminServiceProvider).addTicketReply(
                        companyId,
                        doc.id,
                        message: text,
                        authorEmail: email,
                      );
                      replyController.clear();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) context.showSuccessSnackbar('Reply added');
                      ref.invalidate(supportTicketsProvider);
                    } catch (e) {
                      if (context.mounted) context.showErrorSnackbar('Error: $e');
                    }
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send Reply'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Change Status', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['open', 'inProgress', 'resolved', 'closed'].map((s) {
                  final isCurrent = s == status;
                  return ChoiceChip(
                    label: Text(s),
                    selected: isCurrent,
                    onSelected: isCurrent
                        ? null
                        : (_) async {
                            try {
                              await doc.reference.update({'status': s});
                              final email = FirebaseAuth.instance.currentUser?.email ?? '';
                              ref.read(superAdminServiceProvider).logSuperAdminAction(action: 'ticket_status_changed', actorEmail: email, entityType: 'ticket', entityId: doc.id, details: 'Changed ticket status to $s');
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) context.showSuccessSnackbar('Status updated to $s');
                              ref.invalidate(supportTicketsProvider);
                            } catch (e) {
                              if (context.mounted) context.showErrorSnackbar('Error: $e');
                            }
                          },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => replyController.dispose());
  }
}
