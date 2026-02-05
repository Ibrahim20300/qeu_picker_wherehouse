import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../../helpers/snackbar_helper.dart';
import '../../constants/app_colors.dart';
import '../../services/invoice_service.dart';
import '../../services/api_service.dart';
import 'bags_count_screen.dart';
import 'manual_barcode_screen.dart';
import 'picking_screen.dart';
import 'widgets/pick_result_dialog.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel? order;
  final String? taskId;

  const OrderDetailsScreen({super.key, this.order, this.taskId})
      : assert(order != null || taskId != null, 'Either order or taskId must be provided');

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  late TabController _tabController;

  // تتبع الموقع الحالي لكل منتج (باستخدام الباركود كمفتاح)
  final Map<String, int> _currentLocationIndex = {};

  // لتتبع دايلوج الموقع المفتوح
  bool _isLocationDialogOpen = false;

  // Task data loading
  Map<String, dynamic>? _taskData;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // تحديد الطلب في البروفايدر
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.order != null) {
        context.read<OrdersProvider>().selectOrder(widget.order!.id);
      } else if (widget.taskId != null) {
        _loadTaskDetails();
      }
      // _setupBarcodeScanning();
    });
  }

  Future<void> _loadTaskDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final data = await authProvider.apiService.getTaskDetails(widget.taskId!);
      setState(() {
        _taskData = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل جلب تفاصيل المهمة';
        _isLoading = false;
      });
    }
  }

  Widget _buildTaskDetailsView() {
    final task = _taskData!;
    final orderNumber = task['order_number']?.toString().replaceAll('#', '') ?? '';
    final status = task['status']?.toString() ?? '';
    final totalItems = task['total_items'] ?? 0;
    final pickedItems = task['picked_items'] ?? 0;
    final customerName = task['customer_name'] ?? '';
    final items = task['items'] as List<dynamic>? ?? [];
    final isInProgress = status.toUpperCase() == 'TASK_IN_PROGRESS';
    final isCompleted = status.toUpperCase() == 'TASK_COMPLETED';

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #$orderNumber'),
        backgroundColor: AppColors.primary,
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
                                    'طلب #$orderNumber',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildTaskStatusBadge(status),
                              ],
                            ),
                            if (customerName.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    customerName,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: totalItems > 0 ? pickedItems / totalItems : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                pickedItems == totalItems ? AppColors.success : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$pickedItems / $totalItems منتج',
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
                    ...items.map((item) => _buildTaskItemCard(item as Map<String, dynamic>)),
                  ],
                ),
              ),
            ),
          ),
          // Bottom action button
          if (isInProgress && !isCompleted)
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
                  child: ElevatedButton.icon(
                    onPressed: () => _onResumeTaskPicking(task),
                    icon: const Icon(Icons.play_circle_fill),
                    label: Text(
                      'استكمال التحضير ($pickedItems/$totalItems)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
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

  Future<void> _onResumeTaskPicking(Map<String, dynamic> task) async {
    // Convert task data to OrderModel for PickingScreen
    final order = _convertTaskToOrder(task);

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
      // Refresh task details when returning
      _loadTaskDetails();
    }
  }

  OrderModel _convertTaskToOrder(Map<String, dynamic> task) {
    final items = (task['items'] as List<dynamic>? ?? []).map((item) {
      final itemMap = item as Map<String, dynamic>;

      // Get first barcode from barcodes array
      final barcodes = itemMap['barcodes'] as List<dynamic>? ?? [];
      final barcode = barcodes.isNotEmpty ? barcodes.first.toString() : '';

      // Extract full_code from locations array
      final locationsData = itemMap['locations'] as List<dynamic>? ?? [];
      final locations = locationsData.map((loc) {
        if (loc is Map<String, dynamic>) {
          return loc['full_code']?.toString() ?? '';
        }
        return loc.toString();
      }).where((loc) => loc.isNotEmpty).toList();

      return OrderItem(
        productId: itemMap['product_id']?.toString() ?? '',
        productName: itemMap['product_name']?.toString() ?? '',
        barcode: barcode,
        requiredQuantity: itemMap['ordered_quantity'] ?? 0,
        pickedQuantity: itemMap['picked_quantity'] ?? 0,
        locations: locations.isNotEmpty ? locations : [''],
        imageUrl: itemMap['product_image']?.toString(),
        unitName: itemMap['unit_name']?.toString(),
      );
    }).toList();

    return OrderModel(
      id: task['id']?.toString() ?? '',
      orderNumber: task['order_number']?.toString() ?? '',
      status: _parseTaskStatus(task['status']?.toString() ?? ''),
      items: items,
      createdAt: DateTime.tryParse(task['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  OrderStatus _parseTaskStatus(String status) {
    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
      case 'TASK_ASSIGNED':
        return OrderStatus.pending;
      case 'TASK_IN_PROGRESS':
        return OrderStatus.inProgress;
      case 'TASK_COMPLETED':
        return OrderStatus.completed;
      case 'TASK_CANCELLED':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  Widget _buildTaskStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
        color = AppColors.pending;
        text = 'قيد الانتظار';
        break;
      case 'TASK_ASSIGNED':
        color = Colors.blue;
        text = 'تم التعيين';
        break;
      case 'TASK_IN_PROGRESS':
        color = AppColors.primary;
        text = 'جاري التحضير';
        break;
      case 'TASK_COMPLETED':
        color = AppColors.success;
        text = 'مكتمل';
        break;
      case 'TASK_CANCELLED':
        color = AppColors.error;
        text = 'ملغي';
        break;
      default:
        color = Colors.grey;
        text = status.replaceAll('TASK_', '');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTaskItemCard(Map<String, dynamic> item) {
    final name = item['product_name']?.toString() ?? '';

    // Get first barcode from barcodes array
    final barcodes = item['barcodes'] as List<dynamic>? ?? [];
    final barcode = barcodes.isNotEmpty ? barcodes.first.toString() : '';

    final requiredQty = item['ordered_quantity'] ?? 0;
    final pickedQty = item['picked_quantity'] ?? 0;

    // Get location from locations array
    final locationsData = item['locations'] as List<dynamic>? ?? [];
    final location = locationsData.isNotEmpty && locationsData.first is Map<String, dynamic>
        ? (locationsData.first as Map<String, dynamic>)['full_code']?.toString() ?? ''
        : '';

    final zone = item['zone']?.toString() ?? '';
    final imageUrl = item['product_image']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
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
                    name,
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
                        barcode,
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
                      if (location.isNotEmpty)
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
                                location,
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
                          color: pickedQty == requiredQty
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.pending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$pickedQty / $requiredQty',
                          style: TextStyle(
                            color: pickedQty == requiredQty ? AppColors.success : AppColors.pending,
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
        print('object');
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
    return;
    // إغلاق دايلوج الموقع إذا كان مفتوحاً
    if (_isLocationDialogOpen) {
      Navigator.of(context).pop();
      _isLocationDialogOpen = false;
    }

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
      backgroundColor: AppColors.primary,
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
        child: PickResultDialogWrapper(
          onComplete: (productName) {
            if (Navigator.canPop(dialogContext)) {
              Navigator.pop(dialogContext);
              SnackbarHelper.success(
                context,
                'تم اكتمال $productName',
                floating: true,
              );
            }
          },
        ),
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
    // Show loading state when fetching task details
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل المهمة'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state
    if (_error != null) {
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
                _error!,
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

    // Show task data if loaded from API
    if (_taskData != null) {
      return _buildTaskDetailsView();
    }

    return Consumer<OrdersProvider>(
      builder: (context, provider, child) {
        final order = provider.currentOrder;

        if (order == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildCustomHeader(provider, order),
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
              // _buildHiddenBarcodeField(),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar(OrdersProvider provider) {
    return Container(
      color: AppColors.primaryWithOpacity(0.05),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: provider.remainingItems.isNotEmpty,
              label: Text('${provider.remainingItems.length}'),
              backgroundColor: AppColors.pending,
              child: const Icon(Icons.pending_actions),
            ),
            text: 'متبقي',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: provider.completedItems.isNotEmpty,
              label: Text('${provider.completedItems.length}'),
              backgroundColor: AppColors.success,
              child: const Icon(Icons.check_circle_outline),
            ),
            text: 'مكتمل',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: provider.missingCount > 0,
              label: Text('${provider.missingCount}'),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.error_outline),
            ),
            text: 'مفقود',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(OrdersProvider provider, OrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showOrderBarcode(order),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'keyboard':
                  _openManualBarcode();
                  break;
                case 'print':
                  _printInvoice(order);
                  break;
                case 'share':
                  _shareInvoice(order);
                  break;
                case 'start':
                  _onStartOrder(provider);
                  break;
                case 'complete':
                  _onCompleteOrder(provider, order);
                  break;
                case 'resume':
                  _onResumePicking(order);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (order.status == OrderStatus.pending)
                const PopupMenuItem(
                  value: 'start',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('بدء الطلب'),
                    ],
                  ),
                ),
              if (order.status == OrderStatus.inProgress)
                const PopupMenuItem(
                  value: 'resume',
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_fill, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('استكمال التحضير'),
                    ],
                  ),
                ),
              if (order.status == OrderStatus.inProgress)
                const PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('إكمال الطلب'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'keyboard',
                child: Row(
                  children: [
                    Icon(Icons.keyboard, color: AppColors.pending),
                    SizedBox(width: 8),
                    Text('إدخال باركود يدوي'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('طباعة الفاتورة'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('مشاركة الفاتورة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openManualBarcode() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ManualBarcodeScreen()),
    );

    if (result == null || !mounted) return;

    final barcode = result['barcode'] as String;
    final quantity = result['quantity'] as int;

    for (int i = 0; i < quantity; i++) {
      _handleBarcodeScan(barcode);
    }
  }

  void _showOrderBarcode(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('باركود الطلب', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: order.orderNumber,
                width: 250,
                height: 80,
                drawText: true,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              order.orderNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(OrderModel order) async {
    try {
      await InvoiceService.generateAndPrintInvoice(order);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.error(context, 'حدث خطأ أثناء إنشاء الفاتورة');
      }
    }
  }

  Future<void> _shareInvoice(OrderModel order) async {
    try {
      await InvoiceService.generateAndShareInvoice(order);
    } catch (e) {
    print(e);
      if (mounted) {
        SnackbarHelper.error(context, 'حدث خطأ أثناء مشاركة الفاتورة');
      }
    }
  }

  void _onStartOrder(OrdersProvider provider) async {
    if (widget.order == null) return;

    provider.startOrder(widget.order!.id);

    // فتح صفحة التحضير الاحترافية
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PickingScreen(order: widget.order!),
      ),
    );

    if (result == true && mounted) {
      SnackbarHelper.success(context, 'تم إكمال التحضير بنجاح');
    }
  }

  Future<void> _onResumePicking(OrderModel order) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PickingScreen(order: order),
      ),
    );

    if (result == true && mounted) {
      SnackbarHelper.success(context, 'تم إكمال التحضير بنجاح');
    }
  }

  Future<void> _onCompleteOrder(OrdersProvider provider, OrderModel order) async {
    final bagsCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => BagsCountScreen(orderNumber: order.orderNumber),
      ),
    );

    if (bagsCount == null) return; // User cancelled

    await provider.completeOrder(order.id, bagsCount: bagsCount);
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
          if (order.status == OrderStatus.pending)
            ElevatedButton.icon(
              onPressed: () => _onStartOrder(provider),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('بدء التحضير'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          if (order.status == OrderStatus.inProgress)
            ElevatedButton.icon(
              onPressed: () => _onResumePicking(order),
              icon: const Icon(Icons.play_circle_fill, size: 18),
              label: Text('استكمال (${provider.pickedItemsCount}/${provider.totalItemsCount})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              progress == 1.0 ? AppColors.success : AppColors.primary,
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
                  Icon(Icons.check_circle, size: 64, color: AppColors.success),
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
              final currentLocIndex = _getCurrentLocationIndex(item);
              return _OrderItemCard(
                key: ValueKey('${item.barcode}_${item.pickedQuantity}_${item.isPicked}_$currentLocIndex'),
                item: item,
                currentLocationIndex: currentLocIndex,
                showNotFoundButton: showNotFoundButton,
                canMarkMissing: isInProgress,
                onMarkMissing: () => _showNextLocationOrMarkMissing(item),
              );
            },
          ),
        ),
        if (showNotFoundButton && isPending)
          _buildStartOrderButton(provider),
        if (showNotFoundButton && isInProgress && !canComplete)
          _buildResumePickingButton(order!),
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
      backgroundColor: AppColors.success,
    );
  }

  Widget _buildStartOrderButton(OrdersProvider provider) {
    return _buildBottomButton(
      onPressed: () => _onStartOrder(provider),
      icon: Icons.play_arrow,
      label: 'بدء التحضير',
      backgroundColor: AppColors.primary,
    );
  }

  Widget _buildResumePickingButton(OrderModel order) {
    return _buildBottomButton(
      onPressed: () => _onResumePicking(order),
      icon: Icons.play_circle_fill,
      label: 'استكمال التحضير',
      backgroundColor: AppColors.success,
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
            Icon(Icons.check_circle, size: 64, color: AppColors.success),
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

  void _restoreMissingItem(OrderItem item) {
    context.read<OrdersProvider>().unmarkItemAsMissing(item);
    // إعادة تعيين مؤشر الموقع
    setState(() {
      _currentLocationIndex[item.barcode] = 0;
    });
    SnackbarHelper.success(context, 'تم إعادة ${item.productName} للقائمة');
  }

  /// الحصول على مؤشر الموقع الحالي للمنتج
  int _getCurrentLocationIndex(OrderItem item) {
    return _currentLocationIndex[item.barcode] ?? 0;
  }

  /// عرض دايلوج التنقل بين المواقع
  void _showNextLocationOrMarkMissing(OrderItem item) {
    final currentIndex = _getCurrentLocationIndex(item);

    _isLocationDialogOpen = true;

    showDialog(
      context: context,
      builder: (dialogContext) => _LocationNavigationDialog(
        item: item,
        initialIndex: currentIndex,
        onLocationChanged: (newIndex) {
          setState(() {
            _currentLocationIndex[item.barcode] = newIndex;
          });
        },
        onMarkAsMissing: () {
          _isLocationDialogOpen = false;
          Navigator.pop(dialogContext);
          context.read<OrdersProvider>().markItemAsMissing(item);
        },
      ),
    ).then((_) {
      // عند إغلاق الدايلوج بأي طريقة
      _isLocationDialogOpen = false;
    });
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
        onChanged: (value){
    
        },
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.pending;
      case OrderStatus.inProgress:
        return AppColors.primary;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

/// كارت عنصر الطلب - Widget منفصل للتنظيم
class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final int currentLocationIndex;
  final VoidCallback onMarkMissing;
  final bool showNotFoundButton;
  final bool canMarkMissing;

  const _OrderItemCard({
    super.key,
    required this.item,
    required this.currentLocationIndex,
    required this.onMarkMissing,
    this.showNotFoundButton = true,
    this.canMarkMissing = true,
  });

  /// الموقع الحالي المعروض
  String get currentLocation =>
      item.locations.isNotEmpty && currentLocationIndex < item.locations.length
          ? item.locations[currentLocationIndex]
          : '';

  @override
  Widget build(BuildContext context) {
    final remaining = item.requiredQuantity - item.pickedQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: item.isPicked ? Border.all(color: AppColors.success, width: 2) : null,
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
      height: 150,
      width: double.infinity,
      color: item.isPicked ? AppColors.successWithOpacity(0.1) : Colors.grey[200],
      child: Padding(
        padding: EdgeInsets.only(top: 10,bottom: 10),
        child: Container(
          child: Stack(
            children: [
              Center(
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: Colors.grey,
                      ),
              ),
              _buildStatusBadge(),
              // if (showNotFoundButton && canMarkMissing && !item.isPicked) _buildNotFoundButton(),
            ],
          ),
        ),
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
          color: item.isPicked ? AppColors.success : AppColors.pending,
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
      child: Material(
        color: AppColors.errorWithOpacity( 0.9),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onMarkMissing,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
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
    return Column(
      children: [
        // الموقع الحالي فقط
        Row(
          children: [
            Expanded(child: _buildLocationChip(currentLocation)),
            const SizedBox(width: 8),
            // عدد المواقع المتبقية
    
          ],
        ),
        const SizedBox(height: 12),
        // Quantity
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: item.isPicked
                ? AppColors.successWithOpacity(0.1)
                : AppColors.pendingWithOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.isPicked ? 'مكتمل' : 'متبقي: ',
                style: TextStyle(
                  fontSize: 14,
                  color: item.isPicked ? AppColors.success : AppColors.pending,
                ),
              ),
              Text(
                item.isPicked ? '✓' : '$remaining',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: item.isPicked ? AppColors.success : AppColors.pending,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChip(String location) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryWithOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryWithOpacity( 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            location,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),

                    const Icon(Icons.location_on, color: AppColors.primary, size: 18),

        ],
      ),
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
            style: TextStyle(color: Colors.grey[600], fontSize: 15,fontWeight: FontWeight.bold),
            textDirection: TextDirection.ltr,
          ),
        ],
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
          border: Border.all(color: AppColors.errorWithOpacity( 0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              height: 80,
              width: double.infinity,
              color: AppColors.errorWithOpacity( 0.1),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error,
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
                      color: AppColors.successWithOpacity( 0.9),
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
                  // Locations
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.locations.map((loc) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryWithOpacity( 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            loc,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Required quantity
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorWithOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'المطلوب: ',
                          style: TextStyle(fontSize: 14, color: AppColors.error),
                        ),
                        Text(
                          '${item.requiredQuantity}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
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

/// دايلوج التنقل بين المواقع
class _LocationNavigationDialog extends StatefulWidget {
  final OrderItem item;
  final int initialIndex;
  final Function(int) onLocationChanged;
  final VoidCallback onMarkAsMissing;

  const _LocationNavigationDialog({
    required this.item,
    required this.initialIndex,
    required this.onLocationChanged,
    required this.onMarkAsMissing,
  });

  @override
  State<_LocationNavigationDialog> createState() => _LocationNavigationDialogState();
}

class _LocationNavigationDialogState extends State<_LocationNavigationDialog> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  bool get _isFirstLocation => _currentIndex == 0;
  bool get _isLastLocation => _currentIndex >= widget.item.locations.length - 1;
  String get _currentLocation => widget.item.locations[_currentIndex];

  void _goToNext() {
    if (!_isLastLocation) {
      setState(() {
        _currentIndex++;
      });
      widget.onLocationChanged(_currentIndex);
    }
  }

  void _goToPrevious() {
    if (!_isFirstLocation) {
      setState(() {
        _currentIndex--;
      });
      widget.onLocationChanged(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 28),
          const SizedBox(width: 8),
          Text('الموقع ${_currentIndex + 1} من ${widget.item.locations.length}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.item.productName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // أزرار التنقل والموقع
          Row(
            children: [
              // زر السابق
              IconButton(
                onPressed: _isFirstLocation ? null : _goToPrevious,
                icon: const Icon(Icons.arrow_back_ios),
                color: AppColors.primary,
                disabledColor: Colors.grey[300],
              ),
              // الموقع الحالي
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryWithOpacity( 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryWithOpacity( 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        _currentLocation,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ),
              // زر التالي
              IconButton(
                onPressed: _isLastLocation ? null : _goToNext,
                icon: const Icon(Icons.arrow_forward_ios),
                color: AppColors.primary,
                disabledColor: Colors.grey[300],
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        if (_isLastLocation)
          ElevatedButton.icon(
            onPressed: widget.onMarkAsMissing,
            icon: const Icon(Icons.close),
            label: const Text('مفقود'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
