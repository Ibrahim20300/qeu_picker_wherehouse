import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/orders_provider.dart';
import 'stat_card.dart';

class StatisticsGrid extends StatelessWidget {
  final OrdersProvider provider;

  const StatisticsGrid({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final completedOrders = provider.completedOrders.length;
    final inProgressOrders = provider.inProgressOrders.length;
    final pendingOrders = provider.pendingOrders.length;
    final totalOrders = provider.orders.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'طلبات مكتملة',
                value: '$completedOrders',
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'قيد التنفيذ',
                value: '$inProgressOrders',
                icon: Icons.sync,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'طلبات معلقة',
                value: '$pendingOrders',
                icon: Icons.pending_actions,
                color: AppColors.pending,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'إجمالي الطلبات',
                value: '$totalOrders',
                icon: Icons.shopping_cart,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
