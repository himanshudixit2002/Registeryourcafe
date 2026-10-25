class HelpArticle {
  final String id;
  final String title;
  final String body;
  final String category;
  final List<String> tags;

  const HelpArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.tags = const [],
  });
}

class HelpArticleData {
  static const List<HelpArticle> articles = [
    HelpArticle(
      id: 'getting-started',
      title: 'Getting started',
      body: 'Welcome to RegisterYourCafe! After creating your workspace, you can:\n\n'
          '1. Add tables from the Tables screen\n'
          '2. Add menu items from the Cafe screen\n'
          '3. Register customers from the Customers screen\n'
          '4. Start sessions when customers arrive\n\n'
          'Visit Settings to customize modules, manage staff, and configure your public listing.',
      category: 'Basics',
      tags: ['setup', 'tables', 'menu', 'onboarding'],
    ),
    HelpArticle(
      id: 'manage-tables',
      title: 'Managing tables',
      body: 'Tables are the core of your venue. You can:\n\n'
          '- Add tables with custom names and types\n'
          '- Define table type categories (Pool, Snooker, etc.)\n'
          '- Start timed sessions on tables\n'
          '- Track occupancy and revenue per table\n\n'
          'Go to the Tables tab to manage your floor plan.',
      category: 'Basics',
      tags: ['tables', 'floor', 'sessions'],
    ),
    HelpArticle(
      id: 'cafe-orders',
      title: 'Cafe orders & kitchen',
      body: 'The Cafe module lets you manage food and beverage orders:\n\n'
          '- Create menu items with prices and categories\n'
          '- Take orders linked to tables or customers\n'
          '- Track order status (pending, preparing, ready, served)\n'
          '- Use the Kitchen Display System (KDS) for kitchen staff\n\n'
          'Enable the KDS from the Cafe screen for a full-screen kitchen view.',
      category: 'Operations',
      tags: ['cafe', 'orders', 'kitchen', 'kds'],
    ),
    HelpArticle(
      id: 'customer-management',
      title: 'Customer database',
      body: 'Track your customers and their preferences:\n\n'
          '- Register customers with name, phone, and email\n'
          '- Manage credit/wallet balances\n'
          '- Assign membership plans\n'
          '- View session and order history\n'
          '- Set up credit codes for self-service payments',
      category: 'Operations',
      tags: ['customers', 'credits', 'membership'],
    ),
    HelpArticle(
      id: 'staff-roles',
      title: 'Staff & permissions',
      body: 'Control who can do what in your workspace:\n\n'
          '- Create staff accounts from Settings > Staff & access\n'
          '- Define custom roles with specific permissions\n'
          '- Assign roles to control module access\n'
          '- View the staff directory and manage team members\n'
          '- Track shifts and working hours',
      category: 'Administration',
      tags: ['staff', 'roles', 'permissions', 'access'],
    ),
    HelpArticle(
      id: 'analytics-reports',
      title: 'Analytics & reports',
      body: 'Get insights into your business:\n\n'
          '- Dashboard shows daily summary (revenue, sessions, orders)\n'
          '- Advanced Analytics provides revenue trends, table utilization, and customer insights\n'
          '- Export data as CSV from Settings > Export data\n'
          '- Track expenses to see profit/loss',
      category: 'Administration',
      tags: ['analytics', 'reports', 'dashboard', 'export'],
    ),
    HelpArticle(
      id: 'public-listing',
      title: 'Public listing & booking',
      body: 'Make your venue discoverable:\n\n'
          '- Enable public listing from Settings > Public discovery\n'
          '- Share your public menu link with customers\n'
          '- Allow floor booking requests from guests\n'
          '- Generate QR codes for tables, menu, and venue\n'
          '- Accept guest cafe orders from the landing page',
      category: 'Growth',
      tags: ['public', 'listing', 'booking', 'qr'],
    ),
    HelpArticle(
      id: 'promotions',
      title: 'Promotions & discounts',
      body: 'Drive more business with promotions:\n\n'
          '- Create percentage or flat discounts\n'
          '- Set up happy hour time-based promotions\n'
          '- Generate coupon codes for customers\n'
          '- Promotions auto-apply based on rules\n\n'
          'Manage promotions from the Promotions screen.',
      category: 'Growth',
      tags: ['promotions', 'discounts', 'coupons', 'happy hour'],
    ),
    HelpArticle(
      id: 'billing-tax',
      title: 'Tax & billing setup',
      body: 'Configure your billing preferences:\n\n'
          '- Set up GST/tax rates from Settings > Tax & invoices\n'
          '- Configure invoice numbering prefix\n'
          '- Tax is automatically added to bills when enabled\n'
          '- Digital receipts can be shared with customers',
      category: 'Administration',
      tags: ['tax', 'gst', 'invoice', 'billing'],
    ),
    HelpArticle(
      id: 'subscription',
      title: 'Subscription plans',
      body: 'RegisterYourCafe offers tiered plans:\n\n'
          '- **Free**: Up to 2 staff, 5 tables\n'
          '- **Pro** (\u20B9999/mo): Up to 10 staff, 25 tables, advanced features\n'
          '- **Enterprise** (\u20B92999/mo): Unlimited staff and tables, priority support\n\n'
          'Upgrade from Settings > Subscription & billing.',
      category: 'Account',
      tags: ['subscription', 'plans', 'pricing', 'upgrade'],
    ),
  ];

  static List<String> get categories {
    return articles.map((a) => a.category).toSet().toList();
  }

  static List<HelpArticle> search(String query) {
    if (query.isEmpty) return articles;
    final lower = query.toLowerCase();
    return articles.where((a) =>
      a.title.toLowerCase().contains(lower) ||
      a.body.toLowerCase().contains(lower) ||
      a.tags.any((t) => t.contains(lower))
    ).toList();
  }
}
