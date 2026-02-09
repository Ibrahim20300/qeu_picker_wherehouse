import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order_model.dart';

class PositionsGrid extends StatelessWidget {
  final List<OrderModel> orders;
  final Function(OrderModel order)? onOrderTap;
  final Function(int position)? onEmptyTap;

  const PositionsGrid({
    super.key,
    required this.orders,
    this.onOrderTap,
    this.onEmptyTap,
  });

  // الحصول على لون المربع حسب حالة الطلب
  Color _getPositionColor(OrderModel? order) {
    if (order == null) {
      return Colors.grey.shade300; // فارغ - رمادي
    }

    switch (order.status) {
      case OrderStatus.completed:
        return AppColors.success; // مكتمل - أخضر
      case OrderStatus.pending:
        return AppColors.error; // يحتاج تشييك - أحمر
      case OrderStatus.inProgress:
        return AppColors.warning; // جاري الفحص - أصفر
      case OrderStatus.cancelled:
        return Colors.grey.shade500; // ملغي - رمادي غامق
    }
  }

  // الحصول على لون النص
  Color _getTextColor(OrderModel? order) {
    if (order == null) {
      return Colors.grey.shade600;
    }
    if (order.status == OrderStatus.inProgress) {
      return Colors.black; // نص أسود على خلفية صفراء
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Legend - دليل الألوان
        _buildLegend(),
        const SizedBox(height: 12),

        // Grid - فقط الطلبات الموجودة
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 أعمدة - مربعات أكبر
              crossAxisSpacing: 10,
              mainAxisSpacing: 20,
              childAspectRatio: 1,
            ),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final position = int.tryParse(order.position?.replaceAll('P', '') ?? '0') ?? 0;

              return _buildPositionCell(position, order);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(AppColors.error, S.needsCheck),
          const SizedBox(width: 16),
          _buildLegendItem(AppColors.warning, S.inspectionInProgress),
          const SizedBox(width: 16),
          _buildLegendItem(AppColors.success, S.statusCompleted),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPositionCell(int position, OrderModel? order) {
    final color = _getPositionColor(order);
    final textColor = _getTextColor(order);
    final hasOrder = order != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hasOrder && onOrderTap != null) {
            onOrderTap!(order);
          } else if (!hasOrder && onEmptyTap != null) {
            onEmptyTap!(position);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasOrder ? color.withValues(alpha: 0.8) : Colors.grey.shade400,
              width: hasOrder ? 2 : 1,
            ),
            boxShadow: hasOrder
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$position',
              style: TextStyle(
                color: textColor,
                fontWeight: hasOrder ? FontWeight.bold : FontWeight.normal,
                fontSize: hasOrder ? 20 : 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget منفصل للإحصائيات
class PositionsStats extends StatelessWidget {
  final List<OrderModel> orders;
  final int totalPositions;

  const PositionsStats({
    super.key,
    required this.orders,
    this.totalPositions = 100,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = orders.where((o) => o.status == OrderStatus.completed).length;
    final pendingCount = orders.where((o) => o.status == OrderStatus.pending).length;
    final inProgressCount = orders.where((o) => o.status == OrderStatus.inProgress).length;
    final emptyCount = totalPositions - orders.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              S.needsCheck,
              pendingCount,
              AppColors.error,
              Icons.error_outline,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              S.inspectionInProgress,
              inProgressCount,
              AppColors.warning,
              Icons.pending,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              S.statusCompleted,
              completedCount,
              AppColors.success,
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              S.empty,
              emptyCount,
              Colors.grey,
              Icons.crop_square,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
