import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../login_screen.dart';
import 'order_details_screen.dart';
import 'widgets/order_card.dart';
import 'widgets/profile_card.dart';
import 'widgets/statistics_grid.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showOrderDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحضير الطلبات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart), text: 'الطلبات'),
            Tab(icon: Icon(Icons.person), text: 'حسابي'),
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
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, child) {
        if (ordersProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = ordersProvider.orders;

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) => OrderCard(
            order: orders[index],
            onTap: () => _showOrderDetails(orders[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final ordersProvider = context.watch<OrdersProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ProfileCard(user: currentUser),
          const SizedBox(height: 24),
          _buildSectionTitle('إحصائياتي'),
          const SizedBox(height: 12),
          StatisticsGrid(provider: ordersProvider),
          const SizedBox(height: 32),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
