import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_picker_provider.dart';
import '../../services/invoice_service.dart';
import 'master_picker_account_screen.dart';
import 'pending_exceptions_screen.dart';
import 'task_detail_screen.dart';

class MasterPickerHomeScreen extends StatefulWidget {
  const MasterPickerHomeScreen({super.key});

  @override
  State<MasterPickerHomeScreen> createState() => _MasterPickerHomeScreenState();
}

class _MasterPickerHomeScreenState extends State<MasterPickerHomeScreen> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadExceptions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadTasks(hideLoad: true);
      _loadExceptions(hideLoad: true);
    });
    _barcodeFocusNode.addListener(_keepFocus);
  }

  void _keepFocus() {
    if (!_barcodeFocusNode.hasFocus && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_barcodeFocusNode.hasFocus) {
          _barcodeFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _barcodeFocusNode.removeListener(_keepFocus);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _onBarcodeChanged(String value) {
    final converted = _convertArabicNumbers(value.trim());
    setState(() {
      _searchQuery = converted;
    });
    if (converted.length >= 19) {
      _onBarcodeScanned(value);
    }
  }

  void _loadTasks({bool hideLoad=false}) {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<MasterPickerProvider>();
    provider.init(authProvider.apiService);
    provider.fetchTasks(hideLoad: hideLoad);
  }

  void _loadExceptions({bool hideLoad = false}) {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<MasterPickerProvider>();
    provider.init(authProvider.apiService);
    provider.fetchPendingExceptions(hideLoad: hideLoad);
  }

  String _convertArabicNumbers(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';
    var result = input;
    for (var i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  void _onBarcodeScanned(String barcode) {
    if (barcode.trim().isEmpty) return;

    final provider = context.read<MasterPickerProvider>();
    final scanned = _convertArabicNumbers(barcode.trim());
print(scanned);
    // Barcode format: orderNumber-zone (e.g. "ORD123-Z01")
    final orderNumber = scanned.contains('-')
        ? scanned.substring(0, scanned.lastIndexOf('-'))
        : scanned;

    // Find matching task
    final task = provider.tasks.cast<Map<String, dynamic>>().where((t) {
      final taskOrderNumber = t['order_number']?.toString().replaceAll('#', '') ?? '';
      return taskOrderNumber == orderNumber || taskOrderNumber == scanned;
    }).firstOrNull;

    _barcodeController.clear();
    setState(() => _searchQuery = '');
    _barcodeFocusNode.requestFocus();

    if (task != null) {
      InvoiceService.printFromTask(task);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على طلب: $scanned'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الماستر بيكر'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Consumer<MasterPickerProvider>(
            builder: (context, provider, _) {
              final count = provider.exceptions.length;
              return IconButton(
                icon: count > 0
                    ? Badge(
                        label: Text('$count', style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 28),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingExceptionsScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MasterPickerAccountScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextFormField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              autofocus: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'امسح باركود الطلب...',
                prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _barcodeController.clear();
                    setState(() => _searchQuery = '');
                    _barcodeFocusNode.requestFocus();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _onBarcodeChanged,
              onFieldSubmitted: (value) => _onBarcodeScanned(value),
            ),
          ),
          Expanded(
            child: Consumer<MasterPickerProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadTasks,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد مهام حالياً',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final filteredTasks = _searchQuery.isEmpty
                    ? provider.tasks.cast<Map<String, dynamic>>()
                    : provider.tasks.cast<Map<String, dynamic>>().where((t) {
                        final orderNumber = t['order_number']?.toString().replaceAll('#', '') ?? '';
                        return orderNumber.contains(_searchQuery);
                      }).toList();

                if (filteredTasks.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد نتائج لـ "$_searchQuery"',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(filteredTasks[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status']?.toString() ?? '';
    final orderNumber = task['order_number']?.toString() ?? '';
    final customerName = task['customer_name']?.toString() ?? '';
    final pickerName = task['picker_name']?.toString() ?? '';
    final totalItems = task['total_items'] ?? 0;
    final pickedItems = task['picked_items'] ?? 0;
    final exceptionItems = task['exception_items'] ?? 0;
    final district = task['district']?.toString() ?? '';
    final zoneName = task['zone_name']?.toString() ?? '';
    final slotTime = task['slot_time']?.toString() ?? '';
    final packageCount = task['package_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            if (customerName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(customerName, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(Icons.inventory_2_outlined, '$pickedItems/$totalItems منتج'),
                const SizedBox(width: 8),
                if (exceptionItems > 0) ...[
                  _buildInfoChip(Icons.warning_amber, '$exceptionItems استثناء', color: Colors.orange),
                  const SizedBox(width: 8),
                ],
                _buildInfoChip(Icons.shopping_bag_outlined, '$packageCount كيس'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (district.isNotEmpty)
                  _buildInfoChip(Icons.location_on_outlined, district),
                if (district.isNotEmpty && zoneName.isNotEmpty)
                  const SizedBox(width: 8),
                if (zoneName.isNotEmpty)
                  _buildInfoChip(Icons.grid_view, 'زون $zoneName'),
                if (slotTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.schedule, slotTime),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (pickerName.isNotEmpty) ...[
                  Icon(Icons.badge_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(pickerName, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
                ] else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.print, color: AppColors.primary),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => InvoiceService.printFromTask(task),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
      case 'PENDING':
        color = Colors.orange;
        label = 'قيد الانتظار';
        break;
      case 'TASK_ASSIGNED':
      case 'ASSIGNED':
        color = Colors.indigo;
        label = 'معيّن';
        break;
      case 'TASK_IN_PROGRESS':
      case 'IN_PROGRESS':
        color = Colors.blue;
        label = 'جاري التحضير';
        break;
      case 'TASK_COMPLETED':
      case 'COMPLETED':
        color = Colors.green;
        label = 'مكتمل';
        break;
      case 'TASK_CANCELLED':
      case 'CANCELLED':
        color = Colors.red;
        label = 'ملغي';
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
