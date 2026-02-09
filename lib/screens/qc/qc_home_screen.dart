import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/qc_provider.dart';
import '../../models/qc_check_model.dart';
import 'qc_account_screen.dart';
import 'qc_check_details_screen.dart';

class QCHomeScreen extends StatefulWidget {
  const QCHomeScreen({super.key});

  @override
  State<QCHomeScreen> createState() => _QCHomeScreenState();
}

class _QCHomeScreenState extends State<QCHomeScreen> {
  final _scanController = TextEditingController();
  final _scanFocusNode = FocusNode();
  final _orderSearchController = TextEditingController();
  final _positionSearchController = TextEditingController();
  String _orderQuery = '';
  String _positionQuery = '';
  Timer? _focusTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadChecks();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChecks();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _setupScanning();
    });
  }

  void _setupScanning() {
    _scanController.addListener(_onScanInput);
    _focusTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      _requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  void _requestFocus() {
    if (mounted && !_scanFocusNode.hasFocus) {
      _scanFocusNode.requestFocus();
    }
  }

  void _onScanInput() {
    final input = _scanController.text.trim();
    if (input.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _scanController.text.isNotEmpty) {
        _processScan(_scanController.text.trim());
        _scanController.clear();
      }
    });
  }

  void _processScan(String scannedValue) {
    final qcProvider = context.read<QCProvider>();
    final checks = qcProvider.checks;

    // Parse format: orderNumber-zoneCode (e.g. 2015750277038653267-03)
    String orderPart = scannedValue;
    String? zonePart;
    if (scannedValue.contains('-')) {
      final lastDash = scannedValue.lastIndexOf('-');
      orderPart = scannedValue.substring(0, lastDash);
      zonePart = scannedValue.substring(lastDash + 1);
    }

    // Find matching check by order number
    final match = checks.cast<QCCheckModel?>().firstWhere(
      (c) => c!.orderNumber.contains(orderPart) || orderPart.contains(c.orderNumber),
      orElse: () => null,
    );

    if (match != null) {
      HapticFeedback.mediumImpact();
      if (match.isPending) {
        _onStartCheck(match, initialZoneCode: zonePart);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QCCheckDetailsScreen(check: match, initialZoneCode: zonePart),
          ),
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على طلب: $scannedValue'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    _requestFocus();
  }

  void _loadChecks() {
    final authProvider = context.read<AuthProvider>();
    final qcProvider = context.read<QCProvider>();
    qcProvider.init(authProvider.apiService);
    qcProvider.loadChecks();
  }

  void _onStartCheck(QCCheckModel check, {String? initialZoneCode}) async {
    final qcProvider = context.read<QCProvider>();

    final success = await qcProvider.startCheck(check.id);

    if (!mounted) return;

    if (success) {
      qcProvider.loadChecks();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QCCheckDetailsScreen(check: check, initialZoneCode: initialZoneCode),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qcProvider.startError ?? 'فشل بدء الفحص'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _focusTimer?.cancel();
    _scanController.removeListener(_onScanInput);
    _scanController.dispose();
    _scanFocusNode.dispose();
    _orderSearchController.dispose();
    _positionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة الجودة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QCAccountScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          // _buildHiddenScanField(),
        ],
      ),
    ),
    );
  }

  Widget _buildHiddenScanField() {
    return Positioned(
      left: -1000,
      child: SizedBox(
        width: 1,
        height: 1,
        child: TextField(
          controller: _scanController,
          focusNode: _scanFocusNode,
          autofocus: true,
          textDirection: TextDirection.ltr,
          enableInteractiveSelection: false,
          showCursor: false,
          decoration: const InputDecoration(border: InputBorder.none),
          onChanged: (value) {
            if (value.isEmpty) return;
            if (value.endsWith('\n') || value.endsWith('\r')) {
              final barcode = value.trim();
              if (barcode.isNotEmpty) {
                _processScan(barcode);
              }
              _scanController.clear();
            } else {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted && _scanController.text.isNotEmpty && _scanController.text == value) {
                  final barcode = _scanController.text.trim();
                  if (barcode.isNotEmpty) {
                    _processScan(barcode);
                  }
                  _scanController.clear();
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final qcProvider = context.watch<QCProvider>();

    if (qcProvider.checksLoading && qcProvider.checks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (qcProvider.checksError != null && qcProvider.checks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                qcProvider.checksError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadChecks,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (qcProvider.checks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => qcProvider.loadChecks(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فحوصات',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final orderQ = _orderQuery.trim().toLowerCase();
    final positionQ = _positionQuery.trim();
    var filteredChecks = qcProvider.checks.toList();
    if (orderQ.isNotEmpty) {
      filteredChecks = filteredChecks
          .where((c) => c.orderNumber.toLowerCase().contains(orderQ))
          .toList();
    }
    if (positionQ.isNotEmpty) {
      filteredChecks = filteredChecks
          .where((c) => c.queuePosition.toString() == positionQ)
          .toList();
    }

    return RefreshIndicator(
      onRefresh: () => qcProvider.loadChecks(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _orderSearchController,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'رقم الطلب',
                      hintTextDirection: TextDirection.rtl,
                      prefixIcon: const Icon(Icons.receipt_long, size: 20),
                      suffixIcon: _orderQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _orderSearchController.clear();
                                setState(() => _orderQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _orderQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _positionSearchController,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'الموقع',
            
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _positionQuery = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredChecks.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد نتائج',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filteredChecks.length,
                    itemBuilder: (context, index) {
                      return _buildCheckCard(filteredChecks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckCard(QCCheckModel check) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QCCheckDetailsScreen(check: check),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'P${check.queuePosition}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          check.orderNumber.length > 6
                              ? check.orderNumber.substring(check.orderNumber.length - 6)
                              : check.orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (check.customerName.isNotEmpty)
                          Text(
                            check.customerName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(check.status),
                ],
              ),

              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _buildInfoChip(Icons.shopping_bag_outlined, 'أكياس: ${check.expectedPackageCount}'),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.map_outlined, '${check.zoneTasks.length} مناطق'),
                  const Spacer(),
                  if (check.totalZoneItems > 0)
                    Text(
                      '${check.totalZonePicked}/${check.totalZoneItems} منتج',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),

              // Start button for pending checks
              if (check.isPending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: context.watch<QCProvider>().startLoading
                        ? null
                        : () => _onStartCheck(check),
                    icon: context.watch<QCProvider>().startLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('ابدأ الفحص'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneRow(QCZoneTask zone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              zone.zoneCode,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zone.pickerName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${zone.pickedItems}/${zone.totalItems}',
            style: TextStyle(
              color: zone.pickedItems == zone.totalItems ? AppColors.success : Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (zone.exceptionItems > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${zone.exceptionItems} استثناء',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            '${zone.packageCount} كيس',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(QCStatus status) {
    Color color;
    switch (status) {
      case QCStatus.pending:
        color = Colors.orange;
      case QCStatus.inProgress:
        color = AppColors.primary;
      case QCStatus.passed:
        color = AppColors.success;
      case QCStatus.failed:
        color = AppColors.error;
      case QCStatus.overridden:
        color = Colors.purple;
      case QCStatus.unspecified:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
