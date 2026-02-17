import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_endpoints.dart';

class QCOrderSearchScreen extends StatefulWidget {
  const QCOrderSearchScreen({super.key});

  @override
  State<QCOrderSearchScreen> createState() => _QCOrderSearchScreenState();
}

class _QCOrderSearchScreenState extends State<QCOrderSearchScreen> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _orderData;
  List<dynamic> _zoneTasks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _orderData = null;
      _zoneTasks = [];
    });

    try {
      final apiService = context.read<AuthProvider>().apiService;
      final response = await apiService.get(ApiEndpoints.qcOrderDetails(query));
      final body = apiService.handleResponse(response);

      setState(() {
        _orderData = body;
        _zoneTasks = List.from(body['zone_tasks'] as List<dynamic>? ?? [])
          ..sort((a, b) => (a['zone_code']?.toString() ?? '').compareTo(b['zone_code']?.toString() ?? ''));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalItems => _zoneTasks.fold(0, (sum, zone) {
    final items = (zone as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return sum + items.length;
  });

  int get _pickedItems => _zoneTasks.fold(0, (sum, zone) {
    final z = zone as Map<String, dynamic>;
    return sum + (z['picked_items'] as int? ?? 0);
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.orderDetails),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      maxLength: 19,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(19),
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: S.orderNumber,
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: const Icon(Icons.receipt_long),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
            ],
          ),
        ),
      );
    }

    if (_orderData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              S.search,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildOrderInfo(),
        const SizedBox(height: 16),
        ..._zoneTasks.map((zone) => _buildZoneSection(zone as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildOrderInfo() {
    final data = _orderData!;
    final orderId = data['order_id']?.toString() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildStatChip(Icons.map_outlined, S.zonesCount(_zoneTasks.length)),
                const SizedBox(width: 12),
                _buildStatChip(Icons.inventory, '$_pickedItems / $_totalItems ${S.product}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildZoneSection(Map<String, dynamic> zone) {
    final zoneCode = zone['zone_code']?.toString() ?? '';
    final pickerName = zone['picker_name']?.toString() ?? '';
    final totalItems = zone['total_items'] ?? 0;
    final pickedItems = zone['picked_items'] ?? 0;
    final packageCount = zone['package_count'] ?? 0;
    final items = zone['items'] as List<dynamic>? ?? [];
    final isComplete = pickedItems == totalItems && totalItems > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isComplete ? AppColors.success.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      color: isComplete ? AppColors.success.withValues(alpha: 0.05) : null,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isComplete ? AppColors.success : AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            zoneCode,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pickerName.isNotEmpty)
              Text(pickerName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(
              '$pickedItems/$totalItems ${S.product} - $packageCount ${S.bag}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: isComplete
            ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
            : null,
        children: items.asMap().entries.map((entry) => _buildItemCard(entry.value, entry.key + 1)).toList(),
      ),
    );
  }

  Widget _buildItemCard(dynamic item, int index) {
    final orderItem = OrderItem.fromTaskJson(item as Map<String, dynamic>);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: orderItem.isPicked ? AppColors.successWithOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: orderItem.isPicked ? AppColors.success : Colors.grey.shade300,
          width: orderItem.isPicked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: orderItem.imageUrl != null && orderItem.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: orderItem.imageUrl!,
                      width: 90,
                      height: 90,
                
                      placeholder: (_, __) => Container(
                        width: 56, height: 56,
                        color: Colors.grey[200],
                        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 56, height: 56,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 24),
                      ),
                    )
                  : Container(
                      width: 56, height: 56,
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey[400], size: 24),
                    ),
            ),
            const SizedBox(width: 10),
            // Index
            // CircleAvatar(
            //   radius: 13,
            //   backgroundColor: orderItem.isPicked ? AppColors.success : AppColors.primary,
            //   child: Text(
            //     '$index',
            //     style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            //   ),
            // ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderItem.productName+' '+ '('+(orderItem.unitName!.toString()+')'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (orderItem.barcode.isNotEmpty) ...[
                        Icon(Icons.qr_code, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(orderItem.barcode, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                      ],
                      Icon(Icons.inventory, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(
                        '${orderItem.pickedQuantity}/${orderItem.requiredQuantity}',
                        style: TextStyle(
                          fontSize: 11,
                          color: orderItem.isPicked ? AppColors.success : Colors.grey[600],
                          fontWeight: orderItem.isPicked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (orderItem.locations.isNotEmpty && orderItem.locations.first.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      children: orderItem.locations.map((loc) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(loc, style: const TextStyle(fontSize: 10)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (orderItem.isPicked)
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          ],
        ),
      ),
    );
  }
}
