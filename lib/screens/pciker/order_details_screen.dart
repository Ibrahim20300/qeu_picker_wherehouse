import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../../helpers/snackbar_helper.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // تحديد الطلب في البروفايدر
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().selectOrder(widget.order.id);
      _setupBarcodeScanning();
    });
  }

  void _setupBarcodeScanning() {
    _barcodeController.addListener(_onBarcodeChanged);
    _barcodeFocusNode.addListener(_onFocusChange);
    _requestFocusAndHideKeyboard();
  }

  void _onFocusChange() {
    if (!_barcodeFocusNode.hasFocus && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _requestFocusAndHideKeyboard();
      });
    }
  }

  void _requestFocusAndHideKeyboard() {
    if (mounted) {
      _barcodeFocusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _barcodeFocusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      });
    }
  }

  void _onBarcodeChanged() {
    if (_barcodeController.text.isNotEmpty) {
      final scannedBarcode = _barcodeController.text.trim();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _handleBarcodeScan(scannedBarcode);
          _barcodeController.clear();
        }
      });
    }
  }

  void _handleBarcodeScan(String barcode) {
    final provider = context.read<OrdersProvider>();
    final result = provider.pickItemByBarcode(barcode);

    // عرض الدايلوج فقط في أول مسح أو عند الاكتمال أو عند الخطأ
    if (!result.success || result.isComplete || result.item?.pickedQuantity == 1) {
      _showPickResultDialog(result);
    } else {
      // للمسحات المتكررة، عرض سناك بار فقط
      _showQuickFeedback(result);
    }
  }

  void _showQuickFeedback(PickResult result) {
    final item = result.item!;
    SnackbarHelper.show(
      context,
      '${item.productName} - ${item.pickedQuantity}/${item.requiredQuantity} | متبقي: ${result.remaining}',
      backgroundColor: Colors.blue,
      icon: Icons.add_circle,
      duration: const Duration(seconds: 1),
      floating: true,
    );
  }

  void _showPickResultDialog(PickResult result) {
    // باركود غير موجود أو منتج مفقود
    if (!result.success) {
      SnackbarHelper.error(context, result.message);
      return;
    }

    final ordersProvider = context.read<OrdersProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: ordersProvider,
        child: Consumer<OrdersProvider>(
          builder: (context, provider, child) {
            final currentResult = provider.lastPickResult;

            // إغلاق الدايلوج تلقائياً عند اكتمال المنتج
            if (currentResult?.isComplete == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                  SnackbarHelper.success(
                    this.context,
                    'تم اكتمال ${provider.lastPickedItem?.productName ?? "المنتج"}',
                    floating: true,
                  );
                }
              });
            }

            return AlertDialog(
              title: const _PickResultDialogTitle(),
              content: const _PickResultDialogContent(),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentResult?.isComplete == true
                        ? Colors.green
                        : Colors.blue,
                  ),
                  child: Text(
                      currentResult?.isComplete == true ? 'ممتاز!' : 'استمر'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  void _showNotFoundDialog(OrderItem item) {
    final String bulkNumber = 'BULK-${item.location.split('-').first}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('لم أجد المنتج'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildBulkLocationBox(bulkNumber),
            const SizedBox(height: 16),
            Text(
              'إذا لم تجد المنتج في الـ Bulk أيضاً، يمكنك رفع بلاغ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showReportConfirmationDialog(item);
            },
            icon: const Icon(Icons.report_problem),
            label: const Text('لم اجده'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkLocationBox(String bulkNumber) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2, color: Colors.blue, size: 40),
          const SizedBox(height: 8),
          const Text(
            'اذهب إلى الـ Bulk',
            style: TextStyle(fontSize: 14, color: Colors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            bulkNumber,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  void _showReportConfirmationDialog(OrderItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تأكيد رفع البلاغ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'هل أنت متأكد من رفع بلاغ عن عدم وجود المنتج؟',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              SnackbarHelper.error(context, 'تم الإبلاغ عن عدم وجود ${item.productName}');
            },
            icon: const Icon(Icons.check),
            label: const Text('تأكيد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeFocusNode.removeListener(_onFocusChange);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, child) {
        final order = provider.currentOrder;

        if (order == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(provider, order),
          body: Stack(
            children: [
              Column(
                children: [
                  // _buildOrderHeader(provider, order),
                  if (order.status == OrderStatus.inProgress)
                    _buildProgressBar(provider),
                  _buildTabBar(provider),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildItemsList(provider.remainingItems, showNotFoundButton: true),
                        _buildItemsList(provider.completedItems, showNotFoundButton: false),
                        _buildMissingItemsList(provider.missingItems),
                      ],
                    ),
                  ),
                ],
              ),
              _buildHiddenBarcodeField(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar(OrdersProvider provider) {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).primaryColor,
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: provider.remainingItems.isNotEmpty,
              label: Text('${provider.remainingItems.length}'),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.pending_actions),
            ),
            text: 'متبقي',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: provider.completedItems.isNotEmpty,
              label: Text('${provider.completedItems.length}'),
              backgroundColor: Colors.green,
              child: const Icon(Icons.check_circle_outline),
            ),
            text: 'مكتمل',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: provider.missingCount > 0,
              label: Text('${provider.missingCount}'),
              backgroundColor: Colors.red,
              child: const Icon(Icons.error_outline),
            ),
            text: 'مفقود',
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(OrdersProvider provider, OrderModel order) {
    return AppBar(
      title: Text('الطلب ${order.orderNumber}'),
      actions: [
        if (order.status == OrderStatus.pending)
          TextButton(
            onPressed: () => _onStartOrder(provider),
            child: const Text('بدء الطلب', style: TextStyle(color: Colors.white)),
          ),
        if (order.status == OrderStatus.inProgress)
          TextButton(
            onPressed: () => _onCompleteOrder(provider, order),
            child: const Text('إكمال الطلب', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }

  void _onStartOrder(OrdersProvider provider) {
    provider.startOrder(widget.order.id);
    SnackbarHelper.success(context, 'تم بدء الطلب');
  }

  Future<void> _onCompleteOrder(OrdersProvider provider, OrderModel order) async {
    await provider.completeOrder(order.id);
    if (mounted) {
      SnackbarHelper.success(context, 'تم إكمال الطلب');
      Navigator.pop(context);
    }
  }

  Widget _buildOrderHeader(OrdersProvider provider, OrderModel order) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: statusColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.shopping_cart, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusDisplayName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                ),
                Text(
                  '${provider.totalItemsCount} منتج',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (order.status == OrderStatus.inProgress)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${provider.pickedItemsCount}/${provider.totalItemsCount}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(OrdersProvider provider) {
    final progress = provider.currentOrderProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : Colors.blue,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% مكتمل',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<OrderItem> items, {required bool showNotFoundButton}) {
    final provider = context.watch<OrdersProvider>();
    final order = provider.currentOrder;
    final isInProgress = order?.status == OrderStatus.inProgress;
    final isPending = order?.status == OrderStatus.pending;
    final canComplete = isInProgress && provider.remainingItems.isEmpty;

    if (items.isEmpty && showNotFoundButton) {
      // تاب المتبقي فارغ - يعني كل المنتجات تم التعامل معها
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
                  const SizedBox(height: 16),
                  Text(
                    'تم التعامل مع جميع المنتجات',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          if (canComplete)
            _buildCompleteOrderButton(provider, order!),
        ],
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات مكتملة',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _OrderItemCard(
                key: ValueKey('${item.barcode}_${item.pickedQuantity}_${item.isPicked}'),
                item: item,
                showNotFoundButton: showNotFoundButton,
                onNotFound: () => _showNotFoundDialog(item),
                onMarkMissing: () => _markItemAsMissing(item),
              );
            },
          ),
        ),
        if (showNotFoundButton && isPending)
          _buildStartOrderButton(provider),
        if (showNotFoundButton && canComplete)
          _buildCompleteOrderButton(provider, order!),
      ],
    );
  }

  Widget _buildCompleteOrderButton(OrdersProvider provider, OrderModel order) {
    return _buildBottomButton(
      onPressed: () => _onCompleteOrder(provider, order),
      icon: Icons.check_circle,
      label: 'إكمال الطلب',
      backgroundColor: Colors.green,
    );
  }

  Widget _buildStartOrderButton(OrdersProvider provider) {
    return _buildBottomButton(
      onPressed: () => _onStartOrder(provider),
      icon: Icons.play_arrow,
      label: 'بدء التحضير',
      backgroundColor: Colors.blue,
    );
  }

  Widget _buildBottomButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return Container(
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
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingItemsList(List<OrderItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات مفقودة',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MissingItemCard(
          key: ValueKey('missing_${item.barcode}'),
          item: item,
          onRestore: () => _restoreMissingItem(item),
        );
      },
    );
  }

  void _markItemAsMissing(OrderItem item) {
    final String bulkNumber = 'BULK-${item.location.split('-').first}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
            SizedBox(width: 8),
            Text('تأكيد المنتج المفقود'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.productName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.blue, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                  'اذهب الى  ال bulk للتأكد من عدم توفر المنتج',
                    style: TextStyle(fontSize: 14, color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bulkNumber,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الموقع الأصلي: ${item.location}',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrdersProvider>().markItemAsMissing(item);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(
              //     content: Text('تم تحديد ${item.productName} كمفقود'),
              //     backgroundColor: Colors.red,
              //     action: SnackBarAction(
              //       label: 'تراجع',
              //       textColor: Colors.white,
              //       onPressed: () => _restoreMissingItem(item),
              //     ),
              //   ),
              // );
            },
            icon: const Icon(Icons.close),
            label: const Text('تأكيد مفقود'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _restoreMissingItem(OrderItem item) {
    context.read<OrdersProvider>().unmarkItemAsMissing(item);
    SnackbarHelper.success(context, 'تم إعادة ${item.productName} للقائمة');
  }

  Widget _buildHiddenBarcodeField() {
    return SizedBox(
      width: 1,
      height: 1,
      child: TextField(
        controller: _barcodeController,
        focusNode: _barcodeFocusNode,
        textDirection: TextDirection.ltr,
        showCursor: false,
        autofocus: true,
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
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
}

/// كارت عنصر الطلب - Widget منفصل للتنظيم
class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onNotFound;
  final VoidCallback onMarkMissing;
  final bool showNotFoundButton;

  const _OrderItemCard({
    super.key,
    required this.item,
    required this.onNotFound,
    required this.onMarkMissing,
    this.showNotFoundButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = item.requiredQuantity - item.pickedQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: item.isPicked ? Border.all(color: Colors.green, width: 2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildImageSection(),
            _buildDetailsSection(remaining),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 100,
      width: double.infinity,
      color: item.isPicked ? Colors.green.withValues(alpha: 0.1) : Colors.grey[200],
      child: Stack(
        children: [
          Center(
            child: Icon(
              item.isPicked ? Icons.check_circle : Icons.inventory_2_outlined,
              size: 48,
              color: item.isPicked ? Colors.green : Colors.grey[400],
            ),
          ),
          _buildStatusBadge(),
          if (showNotFoundButton && !item.isPicked) _buildNotFoundButton(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: item.isPicked ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.isPicked ? 'مكتمل ✓' : '${item.pickedQuantity}/${item.requiredQuantity}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNotFoundButton() {
    return Positioned(
      top: 8,
      left: 8,
      child: Row(
        children: [
          // Material(
          //   color: Colors.orange.withValues(alpha: 0.9),
          //   borderRadius: BorderRadius.circular(20),
          //   child: InkWell(
          //     onTap: onNotFound,
          //     borderRadius: BorderRadius.circular(20),
          //     child: const Padding(
          //       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //       child: Row(
          //         mainAxisSize: MainAxisSize.min,
          //         children: [
          //           Icon(Icons.search, color: Colors.white, size: 14),
          //           SizedBox(width: 4),
          //           Text(
          //             'Bulk',
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontWeight: FontWeight.bold,
          //               fontSize: 11,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          // const SizedBox(width: 8),
          Material(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onMarkMissing,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'مفقود',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(int remaining) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildLocationAndQuantityRow(remaining),
          const SizedBox(height: 8),
          _buildBarcodeRow(),
        ],
      ),
    );
  }

  Widget _buildLocationAndQuantityRow(int remaining) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 4),
                Text(
                  item.location,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: item.isPicked
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                item.isPicked ? 'مكتمل' : 'متبقي',
                style: TextStyle(
                  fontSize: 10,
                  color: item.isPicked ? Colors.green : Colors.orange,
                ),
              ),
              Text(
                item.isPicked ? '✓' : '$remaining',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: item.isPicked ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeRow() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            item.barcode,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
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
          color = Colors.orange;
          text = 'مكتمل مسبقاً';
        } else if (result.isComplete) {
          icon = Icons.check_circle;
          color = Colors.green;
          text = 'اكتمل التقاط المنتج!';
        } else {
          icon = Icons.add_circle;
          color = Colors.blue;
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
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: Colors.blue, size: 24),
          const SizedBox(width: 8),
          Text(
            location,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
        _buildQuantityBox('الملتقط', '${item.pickedQuantity}', Colors.green),
        const Text('/', style: TextStyle(fontSize: 32, color: Colors.grey)),
        _buildQuantityBox('المطلوب', '${item.requiredQuantity}', Colors.blue),
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
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'متبقي: $remaining',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
    );
  }
}

/// كارت المنتج المفقود
class _MissingItemCard extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRestore;

  const _MissingItemCard({
    super.key,
    required this.item,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              height: 80,
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.1),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'مفقود',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: onRestore,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.undo, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'إعادة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                item.location,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'المطلوب',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                            Text(
                              '${item.requiredQuantity}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          item.barcode,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
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
