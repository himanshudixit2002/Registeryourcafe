import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/communication.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/communication_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class CommunicationHubScreen extends ConsumerStatefulWidget {
  const CommunicationHubScreen({super.key});

  @override
  ConsumerState<CommunicationHubScreen> createState() =>
      _CommunicationHubScreenState();
}

class _CommunicationHubScreenState
    extends ConsumerState<CommunicationHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Communication'),
          bottom: TabBar(controller: _tab, tabs: const [
            Tab(text: 'Staff chat'),
            Tab(text: 'Reminders'),
            Tab(text: 'Log'),
          ]),
        ),
        body: TabBarView(
          controller: _tab,
          children: const [_ChatTab(), _RemindersTab(), _LogTab()],
        ),
      );
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab();

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<ChatMessage>>(
          stream: CommunicationService(tenant).watchChat(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerList();
            }
            final msgs = snap.data ?? [];
            if (msgs.isEmpty) {
              return Center(
                child: Text('No messages yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              );
            }
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final m = msgs[i];
                final isMe = m.senderUid == user?.uid;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width * 0.7),
                    decoration: BoxDecoration(
                      color: isMe
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(m.senderName,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700)),
                        Text(m.message,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Message...',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () async {
              if (_controller.text.trim().isEmpty || user == null) return;
              await CommunicationService(tenant).sendMessage(ChatMessage(
                id: '',
                senderUid: user.uid,
                senderName: user.name,
                message: _controller.text.trim(),
                timestamp: DateTime.now(),
              ));
              _controller.clear();
            },
            icon: const Icon(Icons.send, size: 20),
          ),
        ]),
      ),
    ]);
  }
}

class _RemindersTab extends ConsumerWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<AutoReminder>>(
      stream: CommunicationService(tenant).watchReminders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final reminders = snap.data ?? [];
        if (reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No auto-reminders',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in reminders) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  title: Text(r.type,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${r.triggerDaysBefore} days before \u2022 ${r.message}'),
                  value: r.isActive,
                  onChanged: (v) =>
                      CommunicationService(tenant).toggleReminder(r.id, v),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _LogTab extends StatelessWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Communication log', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'All customer communications are logged\nautomatically when sent via WhatsApp or SMS.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
