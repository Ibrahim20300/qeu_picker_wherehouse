import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/picking_provider.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import '../../widgets/account_screen.dart';
import 'task_details_screen.dart';

class PickerScreen extends StatefulWidget {
  const PickerScreen({super.key});

  @override
  State<PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<PickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    startPickerStatusTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.orderPreparation),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.shopping_cart), text: S.orders),
            Tab(icon: const Icon(Icons.person), text: S.myAccount),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildAccountTab(),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return const _OrdersTab();
  }

  Widget _buildAccountTab() {
    return const AccountScreen(asPage: false);
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadTasks(hide: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks.where((task) {
      final orderNumber = task['order_number']?.toString() ?? '';
      final customerName = task['customer_name']?.toString() ?? '';
      return orderNumber.contains(_searchQuery) ||
          customerName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _startPicking(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString() ?? '';
    if (taskId.isEmpty) return;

    try {
      final pickingProvider = context.read<PickingProvider>();
      pickingProvider.setApiService(context.read<AuthProvider>().apiService);
      await pickingProvider.startPickingTask(taskId);

      if (mounted) {
        // Navigate to OrderDetailsScreen with taskId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(taskId: taskId, rawTask: task),
          ),
        ).then((_) {
          // Refresh tasks when returning
          _loadTasks();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.failedToStartPreparation),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadTasks({bool hide=false}) async {
    if(hide==false){
          setState(() {
      _isLoading = true;
      _error = null;
    });

    }

    try {
      final pickingProvider = context.read<PickingProvider>();
      pickingProvider.setApiService(context.read<AuthProvider>().apiService);
      final tasks = await pickingProvider.getPickingTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = S.failedToFetchOrders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_tasks.isEmpty) {
      return _buildEmptyState();
    }

    final tasks = _filteredTasks;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: S.search,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${S.remaining}: ${tasks.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(child: Text(S.noOrders, style: TextStyle(color: Colors.grey[600])))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index] as Map<String, dynamic>;
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: Text(S.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  S.noOrders,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final orderNumber = task['order_number']?.toString().replaceAll('#', '') ?? '';
    final status = task['status']?.toString() ?? 'TASK_PENDING';
    final totalItems = task['total_items'] ?? 0;
    final pickedItems = task['picked_items'] ?? 0;
    final customerName = task['customer_name'] ?? '';
    final priority = task['priority']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final taskId = task['id']?.toString() ?? '';

        if(status=="TASK_PENDING"){
          return ;
        }
          if (taskId.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(taskId: taskId, rawTask: task),
            ),
          ).then((_) => _loadTasks());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                S.orderNum(orderNumber.length > 6 ? orderNumber.substring(orderNumber.length - 6) : orderNumber),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (priority == 'PRIORITY_HIGH')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  S.urgent,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (customerName.isNotEmpty)
                          Text(
                            customerName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              // Row(
              //   children: [
              //     Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[500]),
              //     const SizedBox(width: 4),
              //     Text(
              //       '$pickedItems / $totalItems ${S.product}',
              //       style: TextStyle(
              //         color: Colors.grey[600],
              //         fontSize: 13,
              //       ),
              //     ),
              //     const Spacer(),
              //     if (totalItems > 0)
              //       SizedBox(
              //         width: 100,
              //         child: LinearProgressIndicator(
              //           value: totalItems > 0 ? pickedItems / totalItems : 0,
              //           backgroundColor: Colors.grey[200],
              //           valueColor: AlwaysStoppedAnimation<Color>(
              //             pickedItems == totalItems ? AppColors.success : AppColors.primary,
              //           ),
              //         ),
              //       ),
              //   ],
              // ),
              if (status == 'TASK_PENDING' || status == 'TASK_ASSIGNED')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startPicking(task),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(S.startPreparation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
        color = AppColors.pending;
        text = S.statusPending;
        break;
      case 'TASK_ASSIGNED':
        color = Colors.blue;
        text = S.statusAssigned;
        break;
      case 'TASK_IN_PROGRESS':
        color = AppColors.primary;
        text = S.statusInProgress;
        break;
      case 'TASK_COMPLETED':
        color = AppColors.success;
        text = S.statusCompleted;
        break;
      case 'TASK_CANCELLED':
        color = AppColors.error;
        text = S.statusCancelled;
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
}
