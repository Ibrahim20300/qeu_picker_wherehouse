import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_picker_provider.dart';

class PendingExceptionsScreen extends StatefulWidget {
  const PendingExceptionsScreen({super.key});

  @override
  State<PendingExceptionsScreen> createState() => _PendingExceptionsScreenState();
}

class _PendingExceptionsScreenState extends State<PendingExceptionsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadExceptions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadExceptions(hideLoad: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadExceptions({bool hideLoad = false}) {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<MasterPickerProvider>();
    provider.init(authProvider.apiService);
    provider.fetchPendingExceptions(hideLoad: hideLoad);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.pendingExceptions),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExceptions,
          ),
        ],
      ),
      body: Consumer<MasterPickerProvider>(
        builder: (context, provider, _) {
          if (provider.exceptionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.exceptionsError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    provider.exceptionsError!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadExceptions,
                    icon: const Icon(Icons.refresh),
                    label: Text(S.retry),
                  ),
                ],
              ),
            );
          }

          if (provider.exceptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    S.noPendingExceptions,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchPendingExceptions(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.exceptions.length,
              itemBuilder: (context, index) {
                final exception = provider.exceptions[index];
                if (exception is Map<String, dynamic>) {
                  return _buildExceptionCard(exception);
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildExceptionCard(Map<String, dynamic> exception) {
    final orderNumber = exception['order_number']?.toString() ?? '';
    final productName = exception['product_name']?.toString() ?? '';
    final exceptionType = exception['exception_type']?.toString() ?? '';
    final quantity = exception['quantity'] ?? 0;
    final barcode = exception['barcode']?.toString() ?? '';
    final note = exception['note']?.toString() ?? '';
    final createdAt = exception['created_at']?.toString() ?? '';

    String formattedTime = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderNumber.isNotEmpty ? orderNumber : S.exception,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildExceptionTypeChip(exceptionType),
              ],
            ),
            if (productName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      productName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
            if (exceptionType.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.label_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    exceptionType,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(Icons.numbers, '$quantity ${S.quantity}'),
                if (barcode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.qr_code, barcode),
                ],
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.schedule, formattedTime),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleApprove(exception, approved: false),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(S.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(exception, approved: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(S.accept),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleApprove(Map<String, dynamic> exception, {required bool approved}) async {
    final exceptionId = exception['exception_id']?.toString() ?? '';
    if (exceptionId.isEmpty) return;

    final provider = context.read<MasterPickerProvider>();
    final success = await provider.approveException(exceptionId, approved: approved);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? (approved ? S.exceptionAccepted : S.exceptionRejected)
            : S.operationFailed),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildExceptionTypeChip(String type) {
    Color color;
    String label;

    switch (type.toUpperCase()) {
      case 'EXCEPTION_OUT_OF_STOCK':
        color = Colors.red;
        label = S.outOfStock;
        break;
      case 'EXCEPTION_DAMAGED':
        color = Colors.orange;
        label = S.damaged;
        break;
      case 'EXCEPTION_WRONG_ITEM':
        color = Colors.purple;
        label = S.wrongProduct;
        break;
      case 'EXCEPTION_SHORT_QUANTITY':
        color = Colors.amber[800]!;
        label = S.shortQuantity;
        break;
      default:
        color = Colors.grey;
        label = type.replaceAll('EXCEPTION_', '').replaceAll('_', ' ');
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
