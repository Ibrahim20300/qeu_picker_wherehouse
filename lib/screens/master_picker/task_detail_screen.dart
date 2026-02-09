import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class TaskDetailScreen extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final orderNumber = task['order_number']?.toString() ?? '';
    final pickerName = task['picker_name']?.toString() ?? '';
    final status = task['status']?.toString() ?? '';
    final items = (task['items'] as List<dynamic>?) ?? [];
    final totalItems = task['total_items'] ?? items.length;
    final pickedItems = task['picked_items'] ?? 0;
    final exceptionItems = task['exception_items'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(orderNumber, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSummaryChip('$pickedItems/$totalItems', S.product, Colors.blue),
                if (exceptionItems > 0)
                  _buildSummaryChip('$exceptionItems', S.exception, Colors.orange),
                if (pickerName.isNotEmpty)
                  _buildSummaryChip(pickerName, S.pickerLabel, Colors.grey[700]!),
                _buildStatusChip(status),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                return _buildItemCard(context, item, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item, int index) {
    final productName = item['product_name']?.toString() ?? '';
    final barcodes = (item['barcodes'] as List<dynamic>?) ?? [];
    final barcode = barcodes.isNotEmpty ? barcodes.first.toString() : '';
    final locations = (item['locations'] as List<dynamic>?) ?? [];
    final location = locations.isNotEmpty
        ? (locations.first as Map<String, dynamic>)['full_code']?.toString() ?? ''
        : '';
    final orderedQty = item['ordered_quantity'] ?? 0;
    final pickedQty = item['picked_quantity'] ?? 0;
    final status = item['status']?.toString() ?? '';
    final unitName = item['unit_name']?.toString() ?? '';
    final productImage = item['product_image']?.toString() ?? '';

    final Color statusColor;
    final String statusLabel;
    switch (status.toUpperCase()) {
      case 'ITEM_PICKED':
        statusColor = Colors.green;
        statusLabel = S.itemPicked;
        break;
      case 'ITEM_OUT_OF_STOCK':
        statusColor = Colors.red;
        statusLabel = S.outOfStock;
        break;
      case 'ITEM_PENDING':
        statusColor = Colors.orange;
        statusLabel = S.statusPending;
        break;
      case 'ITEM_PARTIALLY_PICKED':
        statusColor = Colors.amber;
        statusLabel = S.partiallyPicked;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                if (productImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      productImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported, size: 24, color: Colors.grey),
                      ),
                    ),
                  ),
                if (productImage.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$index. $productName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$pickedQty / $orderedQty $unitName',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location barcode
            if (location.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(S.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text(location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: location,
                  width: 220,
                  height: 50,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Product barcode
            if (barcode.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(S.productBarcode, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Text(barcode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: barcode,
                  width: 220,
                  height: 50,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
      case 'PENDING':
        color = Colors.orange;
        label = S.statusPending;
        break;
      case 'TASK_ASSIGNED':
      case 'ASSIGNED':
        color = Colors.indigo;
        label = S.assignedStatus;
        break;
      case 'TASK_IN_PROGRESS':
      case 'IN_PROGRESS':
        color = Colors.blue;
        label = S.statusInProgress;
        break;
      case 'TASK_COMPLETED':
      case 'COMPLETED':
        color = Colors.green;
        label = S.statusCompleted;
        break;
      case 'TASK_CANCELLED':
      case 'CANCELLED':
        color = Colors.red;
        label = S.statusCancelled;
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
