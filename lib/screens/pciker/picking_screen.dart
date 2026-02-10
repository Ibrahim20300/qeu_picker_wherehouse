import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../helpers/snackbar_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/picking_provider.dart';
import 'manual_barcode_screen.dart';

/// شاشة التحضير الاحترافية - منتج واحد في كل مرة
class PickingScreen extends StatefulWidget {
  final OrderModel order;

  const PickingScreen({super.key, required this.order});

  @override
  State<PickingScreen> createState() => _PickingScreenState();
}

class _PickingScreenState extends State<PickingScreen> {
  final _scanController = TextEditingController();
  final _scanFocusNode = FocusNode();
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pickingProvider = context.read<PickingProvider>();
      final authProvider = context.read<AuthProvider>();
      pickingProvider.setApiService(authProvider.apiService);
      pickingProvider.startPicking(widget.order);
      _setupScanning();
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
    final provider = context.read<PickingProvider>();
    final result = provider.processScan(scannedValue);

    switch (result) {
      case ScanResult.locationVerified:
        HapticFeedback.mediumImpact();
        SnackbarHelper.success(context, S.locationVerified, floating: true);
        break;
      case ScanResult.barcodeAccepted:
        HapticFeedback.mediumImpact();
        final item = provider.currentItem;
        if (item != null) {
          final remaining = item.requiredQuantity - item.pickedQuantity;
          SnackbarHelper.success(
            context,
            S.picked1Remaining(remaining),
            floating: true,
          );
        }
        break;
      case ScanResult.itemComplete:
        HapticFeedback.mediumImpact();
        _showItemCompleteAnimation(() {
          provider.moveToNextItem();
        });
        break;
      case ScanResult.orderComplete:
        HapticFeedback.mediumImpact();
        _showItemCompleteAnimation(() {
          _showOrderCompleteDialog();
        });
        break;
      case ScanResult.wrongLocation:
        HapticFeedback.heavyImpact();
        SnackbarHelper.error(
          context,
          S.wrongLocation(provider.currentLocation),
          floating: true,
        );
        break;
      case ScanResult.wrongBarcode:
        HapticFeedback.heavyImpact();
        SnackbarHelper.error(context, S.wrongBarcode, floating: true);
        break;
      case ScanResult.scanLocationFirst:
        HapticFeedback.heavyImpact();
        SnackbarHelper.error(
          context,
          S.scanLocationFirst(provider.currentLocation),
          floating: true,
        );
        break;
    }
    _requestFocus();
  }

  void _showItemCompleteAnimation(VoidCallback onComplete) {
    final provider = context.read<PickingProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ItemCompleteDialog(
        itemName: provider.currentItem?.productName ?? '',
        onDismiss: () {
          Navigator.pop(context);
          onComplete();
        },
      ),
    );
  }

  void _showOrderCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, color: AppColors.success, size: 32),
            const SizedBox(width: 8),
            Text(S.orderCompleted),
          ],
        ),
        content: Text(
          S.allProductsPrepared,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: Text(S.review),
          ),
        ],
      ),
    );
  }

  void _showExceptionDialog() {
    final provider = context.read<PickingProvider>();
    final item = provider.currentItem;
    if (item == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _ExceptionReportDialog(
        item: item,
        onSubmit: (exceptionType, quantity, note) async {
          final order = provider.currentOrder;
          if (order == null) return;

          try {
            await provider.reportItemException(
              order.id,
              item.id,
              exceptionType: exceptionType,
              quantity: quantity,
              note: note,
            );

            // Mark as missing locally
            provider.markAsMissing();

            if (mounted) {
              SnackbarHelper.success(context, S.issueReportedSuccess, floating: true);
              if (provider.remainingItems.isEmpty) {
                _showOrderCompleteDialog();
              }
            }
          } catch (e) {
            if (mounted) {
              SnackbarHelper.error(context, S.failedToReport, floating: true);
            }
          }
        },
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
      _processScan(barcode);
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _scanController.removeListener(_onScanInput);
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PickingProvider>(
      builder: (context, provider, _) {
        final item = provider.currentItem;
        final remaining = provider.remainingItems;
        final completed = provider.completedItems;

        if (item == null) {
          return _buildEmptyState();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderLocal(remaining.length, completed.length, provider),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(S.scanLocationFirstHint, style: const TextStyle(fontSize: 16)),
                            SizedBox(height: 8),
                            _buildLocationSection(item, provider),
                            const SizedBox(height: 16),
                            _buildProductCard(item),
                            const SizedBox(height: 16),
                            _buildQuantitySection(item),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _buildHiddenScanField(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.preparation),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              S.noRemainingProducts,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.goBack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLocal(int remaining, int completed, PickingProvider provider) {
    final total = remaining + completed + provider.missingItems.length;
    final apiDone = provider.items.where((i) => i.isPicked && i.status != 'ITEM_PENDING').length;
    final sessionDone = provider.items.where((i) => i.isPicked && i.status == 'ITEM_PENDING').length;
    final done = apiDone + sessionDone + provider.missingItems.length;
    final progress = total > 0 ? (done / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      S.orderNum(widget.order.orderNumber.substring(0, 8)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$done / $total ${S.product}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'missing':
                      _showExceptionDialog();
                      break;
                    case 'manual':
                      _openManualBarcode();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'manual',
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(S.manualBarcodeEntry),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'missing',
                    child: Row(
                      children: [
                        const Icon(Icons.cancel, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(S.reportIssue),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(OrderItem item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // صورة المنتج
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                Center(
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadiusGeometry.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.fitWidth,
                            placeholder: (_, __) => const CircularProgressIndicator(),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.grey,
                        ),
                ),
              ],
            ),
          ),
          // اسم المنتج
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  item.unitName != null && item.unitName!.isNotEmpty
                      ? '${item.productName} (${item.unitName})'
                      : item.productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: (item.barcodes.isNotEmpty ? item.barcodes : [item.barcode])
                      .map((bc) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryWithOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              bc,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(OrderItem item, PickingProvider provider) {
    final color = provider.locationVerified ? AppColors.success : AppColors.warning;
    final hasMultipleLocations = item.locations.length > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            provider.locationVerified ? Icons.check_circle : Icons.location_on,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            provider.currentLocation,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: provider.locationVerified ? AppColors.success : AppColors.textPrimary,
              letterSpacing: 1,
            ),
          ),
          // عرض رقم الموقع الحالي إذا كان هناك مواقع متعددة
          if (hasMultipleLocations) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${provider.currentLocationIndex + 1}/${item.locations.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantitySection(OrderItem item) {
    final remaining = item.requiredQuantity - item.pickedQuantity;
    final unit = item.unitName;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuantityBox(
              S.picked,
              '${item.pickedQuantity}',
              AppColors.success,
              Icons.check_circle_outline,
              unit: unit,
            ),
            Container(
              height: 60,
              width: 1,
              color: Colors.grey[300],
            ),
            _buildQuantityBox(
              S.remaining,
              '$remaining',
              remaining > 0 ? AppColors.pending : AppColors.success,
              Icons.pending_outlined,
              unit: unit,
            ),
            Container(
              height: 60,
              width: 1,
              color: Colors.grey[300],
            ),
            _buildQuantityBox(
              S.required_,
              '${item.requiredQuantity}',
              AppColors.primary,
              Icons.inventory_2_outlined,
              unit: unit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityBox(
      String label, String value, Color color, IconData icon, {String? unit}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (unit != null && unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
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
            print('Scanned: $value');
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
}

/// دايلوج اكتمال المنتج
class _ItemCompleteDialog extends StatefulWidget {
  final String itemName;
  final VoidCallback onDismiss;

  const _ItemCompleteDialog({
    required this.itemName,
    required this.onDismiss,
  });

  @override
  State<_ItemCompleteDialog> createState() => _ItemCompleteDialogState();
}

class _ItemCompleteDialogState extends State<_ItemCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    // إغلاق تلقائي بعد ثانية
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.completed,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.itemName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دايلوج الإبلاغ عن مشكلة في المنتج
class _ExceptionReportDialog extends StatefulWidget {
  final OrderItem item;
  final Future<void> Function(String exceptionType, int quantity, String? note) onSubmit;

  const _ExceptionReportDialog({
    required this.item,
    required this.onSubmit,
  });

  @override
  State<_ExceptionReportDialog> createState() => _ExceptionReportDialogState();
}

class _ExceptionReportDialogState extends State<_ExceptionReportDialog> {
  String? _selectedType;
  late int _quantity;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  static Map<String, Map<String, dynamic>> get _exceptionTypes => {
    'EXCEPTION_OUT_OF_STOCK': {'label': S.outOfStock, 'icon': Icons.remove_shopping_cart, 'color': Colors.orange},
    'EXCEPTION_DAMAGED': {'label': S.damaged, 'icon': Icons.broken_image, 'color': Colors.red},
    'EXCEPTION_EXPIRED': {'label': S.expired, 'icon': Icons.timer_off, 'color': Colors.purple},
    'EXCEPTION_WRONG_ITEM': {'label': S.wrongProduct, 'icon': Icons.swap_horiz, 'color': Colors.blue},
    'EXCEPTION_OTHER': {'label': S.other, 'icon': Icons.more_horiz, 'color': Colors.grey},
  };

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.requiredQuantity - widget.item.pickedQuantity;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        _selectedType!,
        _quantity,
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.report_problem, color: AppColors.error, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.reportIssue,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.productName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(S.issueType, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _exceptionTypes.entries.map((entry) {
                final isSelected = _selectedType == entry.key;
                final color = entry.value['color'] as Color;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.value['icon'] as IconData, size: 16,
                          color: isSelected ? Colors.white : color),
                      const SizedBox(width: 4),
                      Text(entry.value['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: color,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _selectedType = entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Row(
            //   children: [
            //     const Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold)),
            //     const Spacer(),
            //     IconButton(
            //       icon: const Icon(Icons.remove_circle_outline),
            //       onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
            //     ),
            //     Text(
            //       '$_quantity',
            //       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            //     ),
            //     IconButton(
            //       icon: const Icon(Icons.add_circle_outline),
            //       onPressed: _quantity < (widget.item.requiredQuantity - widget.item.pickedQuantity)
            //           ? () => setState(() => _quantity++)
            //           : null,
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 12),
            // TextField(
            //   controller: _noteController,
            //   decoration: InputDecoration(
            //     hintText: 'ملاحظة (اختياري)',
            //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            //     contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            //   ),
            //   maxLines: 2,
            // ),
            // const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedType != null && !_isSubmitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(S.submitReport, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
