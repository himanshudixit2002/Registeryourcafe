import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/table.dart'; // Assuming your table model is SnookerTable

class TableSearchDelegate extends SearchDelegate<SnookerTable?> {
  final TenantRef tenant;

  TableSearchDelegate({required this.tenant});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.colorScheme.primaryContainer,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Please enter a table name.'));
    }
    return _buildSearchResults(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Optionally, show all available tables or recent tables as suggestions initially
    return _buildSearchResults(query);
  }

  Widget _buildSearchResults(String searchQuery) {
    final String normalizedQuery = searchQuery.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: tenant.tables().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tables = snapshot.data!.docs
            .map(
              (doc) => SnookerTable.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }),
            )
            .where((table) {
              // Search by table name
              final nameMatches = table.name.toLowerCase().contains(
                normalizedQuery,
              );
              // You could also filter by status if needed, e.g., only show 'available' tables
              // return nameMatches && table.status == TableStatus.available;
              return nameMatches;
            })
            .toList();

        if (tables.isEmpty) {
          return Center(
            child: Text('No tables found matching "$searchQuery".'),
          );
        }

        return ListView.builder(
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            return ListTile(
              title: Text(table.name),
              subtitle: Text(
                'Status: ${table.status.toString().split('.').last}',
              ),
              onTap: () {
                close(context, table);
              },
            );
          },
        );
      },
    );
  }
}
