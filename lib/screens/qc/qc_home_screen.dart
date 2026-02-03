import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../models/order_model.dart';
import '../login_screen.dart';
import 'qc_order_details_screen.dart';
import 'widgets/positions_grid.dart';

class QCHomeScreen extends StatefulWidget {
  const QCHomeScreen({super.key});

  @override
  State<QCHomeScreen> createState() => _QCHomeScreenState();
}

class _QCHomeScreenState extends State<QCHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
    });
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
        builder: (_) => QCOrderDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة الجودة'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildPositionsGridTab(),
    );
  }

  Widget _buildPositionsGridTab() {
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, child) {
        if (ordersProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = ordersProvider.orders;

        return Column(
          children: [
            // إحصائيات سريعة
            // PositionsStats(orders: orders),

            // الشبكة
            Expanded(
              child: PositionsGrid(
                orders: orders,
                onOrderTap: (order) => _showOrderDetails(order),
                onEmptyTap: (position) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('الموقع $position فارغ'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
