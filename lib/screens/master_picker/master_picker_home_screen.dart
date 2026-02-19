import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_picker_provider.dart';
import '../../services/api_endpoints.dart';
import '../../services/invoice_service.dart';
import 'master_picker_account_screen.dart';
import 'pending_exceptions_screen.dart';
import 'task_detail_screen.dart';
import 'zone_stats_screen.dart';

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
  String? _topPickerName;
  String? _topPickerZone;
  double _topPickerScore = 0;

  @override
  void initState() {
    super.initState();
  

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadTasks(hideLoad: true);
      _loadExceptions(hideLoad: true);
      _loadTopPicker();
    });

   
    _barcodeFocusNode.addListener(_keepFocus);


        WidgetsBinding.instance.addPostFrameCallback((_) {
             _loadTasks();
              _loadExceptions(hideLoad: true);
              _loadTopPicker();
      // _setupScanning();
    });
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

  Future<void> _loadTopPicker() async {
    try {
      final apiService = context.read<AuthProvider>().apiService;
      final response = await apiService.get(ApiEndpoints.pickerZoneStats);
      final body = apiService.handleResponse(response);

      final List<dynamic> zones;
      if (body['zones'] is List) {
        zones = body['zones'] as List<dynamic>;
      } else if (body['data'] is List) {
        zones = body['data'] as List<dynamic>;
      } else {
        zones = [body];
      }

      String? bestName;
      String? bestZone;
      double bestScore = -1;

      for (final zone in zones) {
        final z = zone as Map<String, dynamic>;
        final zoneName = z['zone_name']?.toString() ?? '';
        final pickers = (z['pickers'] as List<dynamic>? ?? []);
        for (final p in pickers) {
          final picker = p as Map<String, dynamic>;
          final score = _pickerScore(picker);
          if (score > bestScore) {
            bestScore = score;
            bestName = picker['picker_name']?.toString() ?? '';
            bestZone = zoneName;
          }
        }
      }

      if (mounted && bestName != null) {
        setState(() {
          _topPickerName = bestName;
          _topPickerZone = bestZone;
          _topPickerScore = bestScore;
        });
      }
    } catch (_) {}
  }

  double _pickerScore(Map<String, dynamic> picker) {
    final last12h = picker['last_12h'] as Map<String, dynamic>? ?? {};
    final tasks = (last12h['tasks_completed'] as num?)?.toDouble() ?? 0;
    final items = (last12h['items_picked'] as num?)?.toDouble() ?? 0;
    final exceptions = (last12h['exceptions'] as num?)?.toDouble() ?? 0;
    final avgTime = (last12h['avg_completion_time_minutes'] as num?)?.toDouble() ?? 0;
    if (tasks == 0) return -1;
    final speedScore = avgTime > 0 ? (20.0 - avgTime).clamp(0, 20) : 0.0;
    final exceptionRate = tasks > 0 ? (exceptions / tasks) : 0.0;
    final qualityScore = (1.0 - exceptionRate).clamp(0, 1) * 100;
    return (tasks * 0.40) + (items * 0.25) + (speedScore * 0.20) + (qualityScore * 0.15);
  }

  String _convertArabicNumbers(String input) {
    const arabic = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
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
          content: Text(S.orderNotFound(scanned)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.masterPickerDashboard),
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
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ZoneStatsScreen()),
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
                hintText: S.scanOrderBarcode,
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
          if (_topPickerName != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, size: 22, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_topPickerName ($_topPickerZone)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _topPickerScore.toStringAsFixed(1),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                    ),
                  ),
                ],
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
                          label: Text(S.retry),
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
                        Text(
                          S.noTasksCurrently,
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                      S.noResultsFor(_searchQuery),
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
                _buildInfoChip(Icons.inventory_2_outlined, '$pickedItems/$totalItems ${S.product}'),
                const SizedBox(width: 8),
                if (exceptionItems > 0) ...[
                  _buildInfoChip(Icons.warning_amber, '$exceptionItems ${S.exception}', color: Colors.orange),
                  const SizedBox(width: 8),
                ],
                _buildInfoChip(Icons.shopping_bag_outlined, '$packageCount ${S.bag}'),
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
                  _buildInfoChip(Icons.grid_view, S.zonePrefix(zoneName)),
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
                ElevatedButton.icon(
                  onPressed: () => InvoiceService.printFromTask(task),
                  icon: const Icon(Icons.print, size: 20),
                  label: Text(S.print_),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
