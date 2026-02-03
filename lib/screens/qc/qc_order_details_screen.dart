import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/invoice_service.dart';

class QCOrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const QCOrderDetailsScreen({super.key, required this.order});

  @override
  State<QCOrderDetailsScreen> createState() => _QCOrderDetailsScreenState();
}

class _QCOrderDetailsScreenState extends State<QCOrderDetailsScreen> {
  final Map<String, bool> _checkedItems = {};
  final Map<String, String> _itemNotes = {};

  @override
  void initState() {
    super.initState();
    // تهيئة حالة الفحص لكل منتج
    for (var item in widget.order.items) {
      _checkedItems[item.productId] = false;
      _itemNotes[item.productId] = '';
    }
  }

  bool get allItemsChecked =>
      _checkedItems.values.every((checked) => checked);

  int get checkedCount =>
      _checkedItems.values.where((checked) => checked).length;

  void _approveOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('تأكيد الموافقة'),
          ],
        ),
        content: const Text('هل تريد الموافقة على هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessAndPrint('تمت الموافقة على الطلب بنجاح');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
  }

  void _rejectOrder() {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('رفض الطلب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال سبب الرفض:'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'سبب الرفض...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم رفض الطلب'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndPrint(String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );

    // طباعة الملصق
    try {
      await InvoiceService.generateAndPrintInvoice(widget.order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الطباعة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فحص الطلب #${widget.order.orderNumber.substring(0, 8)}...'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => InvoiceService.generateAndPrintInvoice(widget.order),
            tooltip: 'طباعة',
          ),
        ],
      ),
      body: Column(
        children: [
          // Order Info Header
          _buildOrderHeader(),

          // Progress Indicator
          _buildProgressBar(),

          // Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.order.items.length,
              itemBuilder: (context, index) => _buildItemCard(
                widget.order.items[index],
                index + 1,
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderInfo('Position', widget.order.position ?? '-', Icons.location_on),
              _buildHeaderInfo('Zone', '${widget.order.zone}/${widget.order.totalZone}', Icons.map),
              _buildHeaderInfo('الحي', widget.order.neighborhood ?? '-', Icons.home),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderInfo('الوقت', widget.order.slotTime ?? '-', Icons.schedule),
              _buildHeaderInfo('التاريخ', widget.order.slotDate ?? '-', Icons.calendar_today),
              _buildHeaderInfo('الأكياس', '${widget.order.bagsCount}', Icons.shopping_bag),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = checkedCount / widget.order.items.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تقدم الفحص',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                '$checkedCount / ${widget.order.items.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1 ? Colors.green : Colors.orange,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, int index) {
    final isChecked = _checkedItems[item.productId] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isChecked ? Colors.green.withValues(alpha: 0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isChecked ? Colors.green : Colors.grey.shade300,
          width: isChecked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() {
                      _checkedItems[item.productId] = value ?? false;
                    });
                  },
                  activeColor: Colors.green,
                ),

                // Index
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isChecked ? Colors.green : Colors.orange,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Product Name
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),

                // Check Icon
                if (isChecked)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),

            const SizedBox(height: 12),

            // Product Details
            Row(
              children: [
                _buildDetailChip(Icons.qr_code, item.barcode),
                const SizedBox(width: 12),
                _buildDetailChip(
                  Icons.inventory,
                  '${item.pickedQuantity}/${item.requiredQuantity}',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Locations
            Wrap(
              spacing: 8,
              children: item.locations.map((loc) => Chip(
                label: Text(loc, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),

            // Quick Actions
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showItemNoteDialog(item),
                  icon: const Icon(Icons.note_add, size: 18),
                  label: const Text('ملاحظة'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _reportItemIssue(item),
                  icon: const Icon(Icons.report_problem, size: 18),
                  label: const Text('مشكلة'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  void _showItemNoteDialog(OrderItem item) {
    final controller = TextEditingController(
      text: _itemNotes[item.productId],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظة: ${item.productName}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'أدخل ملاحظتك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _itemNotes[item.productId] = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _reportItemIssue(OrderItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.report_problem, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('الإبلاغ عن مشكلة: ${item.productName}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIssueOption('منتج تالف', Icons.broken_image),
            _buildIssueOption('كمية خاطئة', Icons.numbers),
            _buildIssueOption('منتج خاطئ', Icons.swap_horiz),
            _buildIssueOption('منتج مفقود', Icons.search_off),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الإبلاغ عن: $label'),
            backgroundColor: Colors.orange,
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reject Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _rejectOrder,
              icon: const Icon(Icons.cancel),
              label: const Text('رفض'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Approve Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: allItemsChecked ? _approveOrder : null,
              icon: const Icon(Icons.check_circle),
              label: Text(allItemsChecked ? 'موافقة وطباعة' : 'افحص جميع المنتجات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
