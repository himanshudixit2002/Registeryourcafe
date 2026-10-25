class SubscriptionPlan {
  final String id;
  final String name;
  final int maxStaff;
  final int maxTables;
  final List<String> features;
  final double monthlyPrice;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.maxStaff,
    required this.maxTables,
    required this.features,
    required this.monthlyPrice,
  });

  static const List<SubscriptionPlan> allPlans = [
    SubscriptionPlan(
      id: 'free',
      name: 'Free',
      maxStaff: 2,
      maxTables: 5,
      features: ['Basic dashboard', 'Table management', 'Customer database'],
      monthlyPrice: 0,
    ),
    SubscriptionPlan(
      id: 'pro',
      name: 'Pro',
      maxStaff: 10,
      maxTables: 25,
      features: [
        'Everything in Free',
        'Advanced analytics',
        'Expense tracking',
        'Promotions & discounts',
        'QR codes',
        'Kitchen display',
        'Data export',
      ],
      monthlyPrice: 999,
    ),
    SubscriptionPlan(
      id: 'enterprise',
      name: 'Enterprise',
      maxStaff: 999999,
      maxTables: 999999,
      features: [
        'Everything in Pro',
        'Unlimited staff',
        'Unlimited tables',
        'Priority support',
        'Custom branding',
        'API access',
        'Multi-venue support',
      ],
      monthlyPrice: 2999,
    ),
  ];

  static SubscriptionPlan findById(String? id) {
    return allPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => allPlans.first,
    );
  }

  bool get isFree => monthlyPrice == 0;
}
