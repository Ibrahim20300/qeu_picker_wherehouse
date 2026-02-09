import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
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
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(S.confirmApproval),
          ],
        ),
        content: Text(S.approveOrderQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessAndPrint(S.orderApproved);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(S.approve),
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
        title: Row(
          children: [
            const Icon(Icons.cancel, color: AppColors.error),
            const SizedBox(width: 8),
            Text(S.rejectOrder),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.enterRejectionReason),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: S.rejectionReasonHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.orderRejected),
                  backgroundColor: AppColors.error,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(S.reject),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndPrint(String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );

    // طباعة الملصق
    try {
      await InvoiceService.generateAndPrintInvoice(widget.order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.printError),
            backgroundColor: AppColors.error,
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
        title: Text(S.checkOrderNum(widget.order.orderNumber.substring(0, 8))),
        backgroundColor: AppColors.pending,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => InvoiceService.generateAndPrintInvoice(widget.order),
            tooltip: S.print_,
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
      color: AppColors.pendingWithOpacity(0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderInfo('Position', widget.order.position ?? '-', Icons.location_on),
              _buildHeaderInfo('Zone', '${widget.order.zone}/${widget.order.totalZone}', Icons.map),
              _buildHeaderInfo(S.district, widget.order.neighborhood ?? '-', Icons.home),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderInfo(S.time, widget.order.slotTime ?? '-', Icons.schedule),
              _buildHeaderInfo(S.date, widget.order.slotDate ?? '-', Icons.calendar_today),
              _buildHeaderInfo(S.bags, '${widget.order.bagsCount}', Icons.shopping_bag),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.pending, size: 20),
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
                S.inspectionProgress,
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
              progress == 1 ? AppColors.success : AppColors.pending,
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
      color: isChecked ? AppColors.successWithOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isChecked ? AppColors.success : Colors.grey.shade300,
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
                  activeColor: AppColors.success,
                ),

                // Index
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isChecked ? AppColors.success : AppColors.pending,
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
                  const Icon(Icons.check_circle, color: AppColors.success),
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
                backgroundColor: AppColors.primaryWithOpacity(0.1),
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
                  label: Text(S.note),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _reportItemIssue(item),
                  icon: const Icon(Icons.report_problem, size: 18),
                  label: Text(S.problem),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
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
        title: Text(S.noteFor(item.productName)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: S.enterNoteHere,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _itemNotes[item.productId] = controller.text;
              });
              Navigator.pop(context);
            },
            child: Text(S.save),
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
            const Icon(Icons.report_problem, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(S.reportIssueFor(item.productName))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIssueOption(S.damagedProduct, Icons.broken_image),
            _buildIssueOption(S.wrongQuantity, Icons.numbers),
            _buildIssueOption(S.wrongProductItem, Icons.swap_horiz),
            _buildIssueOption(S.missingProduct, Icons.search_off),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.error),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.reported(label)),
            backgroundColor: AppColors.pending,
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
              label: Text(S.reject),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
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
              label: Text(allItemsChecked ? S.approveAndPrint : S.checkAllProducts),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
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
