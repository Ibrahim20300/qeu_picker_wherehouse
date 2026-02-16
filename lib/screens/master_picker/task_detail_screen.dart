import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_endpoints.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = (widget.task['items'] as List<dynamic>?) ?? [];
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchItems());
  }

  Future<void> _fetchItems() async {
    final apiService = context.read<AuthProvider>().apiService;
    final orderId = widget.task['order_id']?.toString() ?? '';
    if (orderId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await apiService.get(
        '${ApiEndpoints.masterPickingTasks}?order_id=$orderId',
      );
      final data = apiService.handleResponse(response);

      final tasks = (data['tasks'] as List<dynamic>?) ??
          (data['data'] as List<dynamic>?) ??
          [];

      if (tasks.isNotEmpty) {
        final taskData = tasks.first as Map<String, dynamic>;
        setState(() {
          _items = (taskData['items'] as List<dynamic>?) ?? [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.task['order_number']?.toString() ?? '';
    final pickerName = widget.task['picker_name']?.toString() ?? '';
    final status = widget.task['status']?.toString() ?? '';
    final totalItems = widget.task['total_items'] ?? _items.length;
    final pickedItems = widget.task['picked_items'] ?? 0;
    final exceptionItems = widget.task['exception_items'] ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(orderNumber, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSummaryChip(Icons.inventory_2, '$pickedItems/$totalItems', S.product, Colors.blue),
                if (exceptionItems > 0)
                  _buildSummaryChip(Icons.warning_amber, '$exceptionItems', S.exception, Colors.orange),
                if (pickerName.isNotEmpty)
                  _buildSummaryChip(Icons.person, pickerName, S.pickerLabel, Colors.grey[700]!),
                _buildStatusChip(status),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          // Items grid/list
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          S.noRemainingProducts,
                          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchItems,
                    child: _buildItemsView(screenWidth),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsView(double screenWidth) {
    // Grid for web (wide screens), list for narrow
    if (screenWidth > 800) {
      final crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 900 ? 3 : 2);
      return GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index] as Map<String, dynamic>;
          return _buildItemCard(item, index + 1);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index] as Map<String, dynamic>;
        return _buildItemCard(item, index + 1);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
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
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Stack(
            children: [
              if (productImage.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: productImage,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey[100],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey[100],
                    child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 120,
                  color: Colors.grey[100],
                  child: Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
                ),
              // Index badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$index',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Status badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Quantity bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(S.product, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      Text(
                        '$pickedQty / $orderedQty $unitName',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Location & Barcode
                if (location.isNotEmpty || barcode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(S.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const Spacer(),
                              Text(location, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        if (location.isNotEmpty && barcode.isNotEmpty)
                          Divider(height: 16, color: Colors.grey[200]),
                        if (barcode.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(S.productBarcode, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  barcode,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
