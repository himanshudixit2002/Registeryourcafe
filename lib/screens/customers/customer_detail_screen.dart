import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../auth/permission_id.dart';
import '../../models/customer.dart';
import '../../models/membership_type_definition.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart'
    show singleCustomerProvider, customerListProvider;
import '../../providers/membership_type_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/credit_service.dart';
import '../../services/membership_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_indicator.dart';
import '../../services/whatsapp_service.dart';
import 'customer_detail/customer_actions_column.dart';
import 'customer_detail/customer_profile_section.dart';
import 'edit_customer_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Future<void> _updateMembership(
    BuildContext context,
    ThemeData theme,
    Customer currentCustomer,
    MembershipTypeDefinition newPlan,
    PaymentMethod? paymentMethod,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsCustomersAdmin)) {
      if (!context.mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.errorContainer,
          content: Text(
            'You do not have permission to change membership.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Membership Change'),
          content: Text(
            'Change ${currentCustomer.name}\'s plan to ${newPlan.name}?\n'
            'Fee: ₹${newPlan.fee}, Credits: ${newPlan.creditsToAdd} Cr, '
            'Duration: ${newPlan.durationInDays != null ? "${newPlan.durationInDays} days" : "Open"}',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(AppStrings.cancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Confirm Change'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        if (context.mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.errorContainer,
              content: Text(
                'No company context',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          );
        }
        return;
      }
      DateTime? newExpiry;
      if (newPlan.durationInDays != null) {
        newExpiry = DateTime.now().add(Duration(days: newPlan.durationInDays!));
      }

      String? newMembershipId;

      if (!newPlan.isRegular) {
        final previousRecord = currentCustomer.membershipHistory.firstWhere(
          (rec) => rec.type == newPlan.id,
          orElse: () => MembershipRecord(id: '', type: '', active: false),
        );

        if (previousRecord.id.isNotEmpty) {
          newMembershipId = previousRecord.id;
        } else {
          newMembershipId = await MembershipService.generateMembershipId(
            tenant,
            newPlan,
          );
        }
      }

      final List<Map<String, dynamic>> updatedHistory = currentCustomer
          .membershipHistory
          .map((e) {
            final map = e.toMap();
            map['active'] = (e.type == newPlan.id);
            return map;
          })
          .toList();

      final exists = updatedHistory.any((h) => h['type'] == newPlan.id);
      if (!exists && newMembershipId != null) {
        updatedHistory.add({
          'id': newMembershipId,
          'type': newPlan.id,
          'active': true,
        });
      }

      final user = ref.read(appUserProvider).value;
      final batch = tenant.db.batch();
      final custRef = tenant.customers().doc(currentCustomer.id);

      batch.update(custRef, {
        'membershipType': newPlan.isRegular
            ? kRegularMembershipTypeId
            : newPlan.id,
        'membershipId': ?newMembershipId,
        'membershipIds': updatedHistory,
        'membershipExpiry': newExpiry != null
            ? Timestamp.fromDate(newExpiry)
            : null,
        'alerts.membershipExpiry':
            newExpiry != null &&
            newExpiry.difference(DateTime.now()).inDays <= 7,
      });

      if (newPlan.creditsToAdd > 0) {
        CreditService.creditCredits(
          tenant: tenant,
          batch: batch,
          customerId: currentCustomer.id,
          amount: newPlan.creditsToAdd.toDouble(),
          reference: CreditReference.manualAdjustment(
            reason: 'Membership: ${newPlan.name}',
          ),
          performedBy: user,
          note: 'Membership upgrade credits (${newPlan.name})',
          transactionType: CreditService.typeMembership,
        );
      }

      batch.set(tenant.membershipPayments().doc(), {
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'amount': newPlan.fee,
        'paymentMethod': (paymentMethod ?? PaymentMethod.cash).name
            .toLowerCase(),
        'customerId': currentCustomer.id,
        'type': 'membership',
      });

      await batch.commit();

      ref.invalidate(singleCustomerProvider(widget.customerId));
      ref.invalidate(customerListProvider);

      if (!context.mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.primaryContainer,
          content: Text(
            'Membership updated to ${newPlan.name}!',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final ecs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ecs.errorContainer,
          content: Text(
            'Error updating membership: $e',
            style: TextStyle(color: ecs.onErrorContainer),
          ),
        ),
      );
    }
  }

  Future<void> _addCreditsManual(
    Customer customer,
    double amount,
    PaymentMethod method,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsCustomersAdmin)) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.errorContainer,
          content: Text(
            'You do not have permission to add credits.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
        ),
      );
      return;
    }

    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'No company context',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
      return;
    }
    final newCredits = customer.credits + amount;
    final creditTx = CreditTopUp(
      date: DateTime.now(),
      amount: amount,
      paymentMethod: method,
    );
    final user = ref.read(appUserProvider).value;

    final batch = tenant.db.batch();
    final custRef = tenant.customers().doc(customer.id);

    batch.update(custRef, {
      'lastCreditTopUp': creditTx.toFirestore(),
      'alerts.lowCredit': newCredits < 500,
    });

    CreditService.creditCredits(
      tenant: tenant,
      batch: batch,
      customerId: customer.id,
      amount: amount,
      reference: CreditReference.manualAdjustment(
        reason: 'Manual credit top-up',
      ),
      performedBy: user,
      note: 'Manual credit top-up via ${method.name.toUpperCase()}',
      transactionType: CreditService.typeTopUp,
    );

    batch.set(tenant.membershipPayments().doc(), {
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'amount': amount,
      'paymentMethod': method.name.toLowerCase(),
      'customerId': customer.id,
      'type': 'manualTopUp',
    });
    await batch.commit();

    ref.invalidate(singleCustomerProvider(widget.customerId));
    if (mounted) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.primaryContainer,
          content: Text(
            'Credits added successfully',
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
      );
    }
  }

  Future<void> _reconcileCredits(
    Customer customer,
    double ledgerBalance,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsCustomersAdmin)) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.errorContainer,
          content: Text(
            'You do not have permission to reconcile credits.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
        ),
      );
      return;
    }

    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'No company context',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
      return;
    }
    final custRef = tenant.customers().doc(customer.id);
    await custRef.update({
      'credits': ledgerBalance,
      'alerts.lowCredit': ledgerBalance < 500,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(singleCustomerProvider(widget.customerId));
  }

  @override
  Widget build(BuildContext context) {
    final customerAsyncValue = ref.watch(
      singleCustomerProvider(widget.customerId),
    );
    final perms = ref.watchResolvedPermissions();
    final bool canCustomersAdmin = perms.can(PermissionIds.opsCustomersAdmin);
    final bool canSeeCreditCode = perms.can(PermissionIds.navCustomers);
    if (!canSeeCreditCode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customer Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('You do not have access to customer details.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Customer Details',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        centerTitle: isMobile,
        actions: [
          if (canCustomersAdmin)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Customer',
              onPressed: () {
                HapticFeedback.lightImpact();
                if (customerAsyncValue.hasValue) {
                  Navigator.push(
                    context,
                    AppMaterialPageRoute<void>(
                      builder: (context) => EditCustomerScreen(
                        customer: customerAsyncValue.value!,
                      ),
                    ),
                  );
                }
              },
            ),
          if (customerAsyncValue.hasValue && canCustomersAdmin)
            Builder(
              builder: (context) {
                final customer = customerAsyncValue.value!;
                if (customer.creditCode.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Send Code via WhatsApp',
                  onPressed: () async {
                    try {
                      await WhatsAppService.sendCreditCode(
                        rawPhone: customer.phoneNumber,
                        customerName: customer.name,
                        creditCode: customer.creditCode,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        final cs = Theme.of(context).colorScheme;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: cs.errorContainer,
                            content: Text(
                              e.toString(),
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
        ],
      ),
      body: customerAsyncValue.when(
        data: (customer) {
          if (customer == null) {
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.person_off_outlined,
                message: 'Customer not found',
              ),
            );
          }
          final membershipDefs = ref
              .watch(membershipTypeDefinitionsProvider)
              .maybeWhen(
                data: (d) => d,
                orElse: () => <MembershipTypeDefinition>[],
              );
          return LayoutBuilder(
            builder: (context, constraints) {
              final profile = CustomerProfileSection(
                customer: customer,
                canSeeCreditCode: canSeeCreditCode,
                membershipDefs: membershipDefs,
              );
              final actions = CustomerActionsColumn(
                customer: customer,
                membershipDefs: membershipDefs,
                canCustomersAdmin: canCustomersAdmin,
                onUpdateMembership: _updateMembership,
                onAddCreditsManual: _addCreditsManual,
                onReconcileCredits: _reconcileCredits,
              );
              if (constraints.maxWidth > AppTheme.kTabletBreakpoint) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 3,
                      child: SingleChildScrollView(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                        child: profile,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppTheme.subtleDividerColor(theme),
                    ),
                    Flexible(
                      flex: 4,
                      child: SingleChildScrollView(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                        child: actions,
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: Column(
                  children: [
                    profile,
                    const SizedBox(height: AppTheme.kSpacingMedium),
                    Divider(
                      thickness: 1,
                      color: AppTheme.subtleDividerColor(theme),
                    ),
                    const SizedBox(height: AppTheme.kSpacingMedium),
                    actions,
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) =>
            Center(child: Text('Error loading customer: $err')),
      ),
    );
  }
}
