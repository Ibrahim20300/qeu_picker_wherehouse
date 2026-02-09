import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import '../../providers/auth_provider.dart';
import '../../providers/picking_provider.dart';
import '../../models/order_model.dart';
import '../../models/task_details_model.dart';
import '../../helpers/snackbar_helper.dart';
import '../../constants/app_colors.dart';
import 'bags_count_screen.dart';
import 'picking_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTaskDetails();
    });
  }

  Future<void> _loadTaskDetails() async {
    final pickingProvider = context.read<PickingProvider>();
    pickingProvider.setApiService(context.read<AuthProvider>().apiService);
    await pickingProvider.loadTaskDetails(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    final pickingProvider = context.watch<PickingProvider>();

    // Show full-screen loader only on initial load (no data yet)
    if (pickingProvider.taskDetailsLoading && pickingProvider.taskDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المهمة'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (pickingProvider.taskDetailsError != null && pickingProvider.taskDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المهمة'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                pickingProvider.taskDetailsError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTaskDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (pickingProvider.taskDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المهمة'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildTaskDetailsView();
  }

  Widget _buildTaskDetailsView() {
    final pickingProvider = context.watch<PickingProvider>();
    final task = pickingProvider.taskDetails!;
    final items = task.items;

    final actualPicked = items.where((item) => item.status != 'ITEM_PENDING').length;
    final allDone = !items.any((item) => item.status == 'ITEM_PENDING') && task.totalItems > 0;
    final progress = task.totalItems > 0 ? actualPicked / task.totalItems : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${task.orderNumber.length > 6 ? task.orderNumber.substring(task.orderNumber.length - 6) : task.orderNumber}'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code,color: Colors.white,),
            onPressed: () => _showBarcodeDialog(task),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTaskDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order info card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'طلب #${task.orderNumber.length > 6 ? task.orderNumber.substring(task.orderNumber.length - 6) : task.orderNumber}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildTaskStatusBadge(task.status),
                              ],
                            ),
                            if (task.customerName.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.customerName,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                allDone ? AppColors.success : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$actualPicked / ${task.totalItems} منتج',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Items list
                    const Text(
                      'المنتجات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) => _buildTaskItemCard(item)),
                  ],
                ),
              ),
            ),
          ),
          // Bottom action buttons
          if (task.isInProgress && !task.isCompleted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: allDone
                      ? ElevatedButton.icon(
                          onPressed: () => _onCompleteTask(task),
                          icon: const Icon(Icons.check_circle),
                          label: const Text(
                            'إكمال الطلب',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _onResumeTaskPicking(task),
                          icon: const Icon(Icons.play_circle_fill),
                          label: Text(
                            'التحضير الآن  ($actualPicked/${task.totalItems})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onResumeTaskPicking(TaskDetailsModel task) async {
    final order = task.toOrderModel();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PickingScreen(order: order),
      ),
    );

    if (result == true && mounted) {
      SnackbarHelper.success(context, 'تم إكمال التحضير بنجاح');
      Navigator.pop(context);
    } else {
      _loadTaskDetails();
    }
  }

  Future<void> _onCompleteTask(TaskDetailsModel task) async {
    final orderNumber = task.orderNumber;
    final taskId = task.id;

    final bagsCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => BagsCountScreen(orderNumber: orderNumber),
      ),
    );

    if (bagsCount == null || !mounted) return;

    try {
      final pickingProvider = context.read<PickingProvider>();
      final authProvider = context.read<AuthProvider>();

      pickingProvider.setApiService(authProvider.apiService);
      await pickingProvider.completeTaskById(taskId, bagsCount);

      pickingProvider.reset();

      if (mounted) {
        SnackbarHelper.success(context, 'تم إكمال الطلب بنجاح');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.error(context, 'فشل إكمال الطلب. حاول مرة أخرى');
      }
    }
  }

  void _showBarcodeDialog(TaskDetailsModel task) {
    final barcodeData = task.orderNumber;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'باركود الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              bw.BarcodeWidget(
                barcode: bw.Barcode.code128(),
                data: barcodeData,
                width: 250,
                height: 80,
                drawText: true,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusBadge(TaskStatus status) {
    Color color;
    switch (status) {
      case TaskStatus.pending:
        color = AppColors.pending;
      case TaskStatus.assigned:
        color = Colors.blue;
      case TaskStatus.inProgress:
        color = AppColors.primary;
      case TaskStatus.completed:
        color = AppColors.success;
      case TaskStatus.cancelled:
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTaskItemCard(OrderItem item) {
    final zone = item.zone ?? '';
    final pickingProvider = context.read<PickingProvider>();
    final isMissing = pickingProvider.missingItems.any((m) => m.productId == item.productId)
        || item.status == 'ITEM_OUT_OF_STOCK';
    final pickedCount = item.pickedQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2, color: Colors.grey),
              ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.qr_code, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        item.barcode,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (zone.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            zone,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (item.primaryLocation.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                item.primaryLocation,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isMissing
                              ? AppColors.error.withValues(alpha: 0.1)
                              : pickedCount >= item.requiredQuantity
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.pending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMissing ? 'مفقود' : '$pickedCount / ${item.requiredQuantity}',
                          style: TextStyle(
                            color: isMissing
                                ? AppColors.error
                                : pickedCount >= item.requiredQuantity
                                    ? AppColors.success
                                    : AppColors.pending,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (item.unitName != null && item.unitName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.unitName!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
