import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/help_article.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'submit_ticket_screen.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    final categories = HelpArticleData.categories;
    final articles = _searchQuery.isNotEmpty
        ? HelpArticleData.search(_searchQuery)
        : _selectedCategory != null
            ? HelpArticleData.articles.where((a) => a.category == _selectedCategory).toList()
            : HelpArticleData.articles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help center'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SubmitTicketScreen()),
            ),
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Support'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search help articles...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v;
                if (v.isNotEmpty) _selectedCategory = null;
              }),
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
                ),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  for (final cat in categories) ...[
                    const SizedBox(width: 8),
                    _CategoryChip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: articles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No articles found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: AppTheme.scrollPhysicsFor(context),
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
                      AppTheme.kSpacingSmall,
                      isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
                      AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ArticleTile(article: articles[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final HelpArticle article;
  const _ArticleTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: InkWell(
        onTap: () => _showArticle(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    article.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    article.category,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              article.body.length > 120 ? '${article.body.substring(0, 120)}...' : article.body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticle(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                article.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(article.category, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              Text(
                article.body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
