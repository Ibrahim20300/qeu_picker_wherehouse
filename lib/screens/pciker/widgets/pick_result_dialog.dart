import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../providers/orders_provider.dart';

/// Wrapper لدايلوج نتيجة الالتقاط مع دعم الإغلاق التلقائي
class PickResultDialogWrapper extends StatelessWidget {
  final void Function(String productName)? onComplete;

  const PickResultDialogWrapper({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, child) {
        final currentResult = provider.lastPickResult;

        // إغلاق الدايلوج تلقائياً عند اكتمال المنتج
        if (currentResult?.isComplete == true && onComplete != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onComplete!(provider.lastPickedItem?.productName ?? 'المنتج');
          });
        }

        return AlertDialog(
          title: const _PickResultDialogTitle(),
          content: const _PickResultDialogContent(),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentResult?.isComplete == true
                    ? AppColors.success
                    : AppColors.primary,
              ),
              child: Text(
                  currentResult?.isComplete == true ? 'ممتاز!' : 'استمر'),
            ),
          ],
        );
      },
    );
  }
}

/// عنوان دايلوج نتيجة الالتقاط
class _PickResultDialogTitle extends StatelessWidget {
  const _PickResultDialogTitle();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, child) {
        final result = provider.lastPickResult;
        if (result == null) return const SizedBox.shrink();

        IconData icon;
        Color color;
        String text;

        if (result.alreadyComplete) {
          icon = Icons.info;
          color = AppColors.pending;
          text = 'مكتمل مسبقاً';
        } else if (result.isComplete) {
          icon = Icons.check_circle;
          color = AppColors.success;
          text = 'اكتمل التقاط المنتج!';
        } else {
          icon = Icons.add_circle;
          color = AppColors.primary;
          text = 'تم التقاط 1';
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        );
      },
    );
  }
}

/// محتوى دايلوج نتيجة الالتقاط
class _PickResultDialogContent extends StatelessWidget {
  const _PickResultDialogContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, child) {
        final result = provider.lastPickResult;
        final item = provider.lastPickedItem;

        if (result == null || item == null) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildLocationBox(item.location),
            const SizedBox(height: 16),
            _buildQuantityRow(item),
            if (!result.alreadyComplete && !result.isComplete) ...[
              const SizedBox(height: 16),
              _buildRemainingBadge(result.remaining),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLocationBox(String location) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryWithOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            location,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityRow(OrderItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuantityBox('الملتقط', '${item.pickedQuantity}', AppColors.success),
        const Text('/', style: TextStyle(fontSize: 32, color: Colors.grey)),
        _buildQuantityBox('المطلوب', '${item.requiredQuantity}', AppColors.primary),
      ],
    );
  }

  Widget _buildQuantityBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingBadge(int remaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pendingWithOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'متبقي: $remaining',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.pending,
        ),
      ),
    );
  }
}
