import 'package:flutter/material.dart';
import '../../../models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.inProgress:
        return Colors.blue;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildDetails(),
              if (order.status == OrderStatus.inProgress) ...[
                const SizedBox(height: 8),
                _buildProgressBar(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.shopping_cart, color: _statusColor),
        const SizedBox(width: 8),
        Text(
          order.orderNumber,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            order.statusDisplayName,
            style: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '${order.totalItems} منتج',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(width: 16),
        if (order.status == OrderStatus.inProgress) ...[
          Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${order.pickedItems}/${order.totalItems} مكتمل',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: order.progress,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
    );
  }
}
