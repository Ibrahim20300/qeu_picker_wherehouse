import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../helpers/snackbar_helper.dart';

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

  int _currentItemIndex = 0;
  int _currentLocationIndex = 0;
  bool _locationVerified = false;

  // Local state for items
  late List<OrderItem> _items;
  List<OrderItem> _completedItems = [];
  List<OrderItem> _missingItems = [];

  List<OrderItem> get _remainingItems => _items.where((item) =>
      !item.isPicked && !_missingItems.contains(item)).toList();

  OrderItem? get _currentItem {
    final remaining = _remainingItems;
    if (remaining.isEmpty) return null;
    if (_currentItemIndex >= remaining.length) {
      _currentItemIndex = 0;
    }
    return remaining[_currentItemIndex];
  }

  String get _currentLocation {
    final item = _currentItem;
    if (item == null || item.locations.isEmpty) return '';
    if (_currentLocationIndex >= item.locations.length) {
      _currentLocationIndex = 0;
    }
    return item.locations[_currentLocationIndex];
  }

  @override
  void initState() {
    super.initState();
    // Initialize local state from the passed order
    _items = List.from(widget.order.items);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupScanning();
    });
  }

  void _setupScanning() {
    _scanController.addListener(_onScanInput);
    // استدعاء _requestFocus كل 50ms
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
    if (!_locationVerified) {
      // التحقق من الموقع أولاً
      _verifyLocation(scannedValue);
    } else {
      // مسح الباركود بعد التحقق من الموقع
      _scanBarcode(scannedValue);
    }
    _requestFocus();
  }

  void _verifyLocation(String scannedLocation) {
    print(scannedLocation);
    final currentLoc = _currentLocation;
    print(currentLoc);
    final item = _currentItem;

    // تحقق إذا كان المستخدم مسح باركود المنتج بدلاً من الموقع
    if (item != null && scannedLocation == item.barcode) {
      HapticFeedback.heavyImpact();
      SnackbarHelper.error(
        context,
        'امسح الموقع أولاً! ($currentLoc)',
        floating: true,
      );
      return;
    }

    if (scannedLocation.toUpperCase() == currentLoc.toUpperCase()) {
      setState(() {
        _locationVerified = true;
      });
      HapticFeedback.mediumImpact();
      SnackbarHelper.success(context, 'تم التحقق من الموقع ✓', floating: true);
    } else {
      HapticFeedback.heavyImpact();
      SnackbarHelper.error(
        context,
        'موقع خاطئ! المطلوب: $currentLoc',
        floating: true,
      );
    }
  }

  void _scanBarcode(String barcode) {
    final item = _currentItem;
    if (item == null) return;

    if (barcode == item.barcode) {
      // Update local state
      setState(() {
        item.pickedQuantity++;
        if (item.pickedQuantity >= item.requiredQuantity) {
          item.isPicked = true;
        }
      });

      final remaining = item.requiredQuantity - item.pickedQuantity;
      final isComplete = item.isPicked;

      HapticFeedback.mediumImpact();

      if (isComplete) {
        // المنتج اكتمل - الانتقال للمنتج التالي
        _showItemCompleteAnimation(() {
          _moveToNextItem();
        });
      } else {
        // تحديث العداد فقط
        SnackbarHelper.success(
          context,
          'تم التقاط 1 - المتبقي: $remaining',
          floating: true,
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      SnackbarHelper.error(context, 'باركود خاطئ!', floating: true);
    }
  }

  void _showItemCompleteAnimation(VoidCallback onComplete) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ItemCompleteDialog(
        itemName: _currentItem?.productName ?? '',
        onDismiss: () {
          Navigator.pop(context);
          onComplete();
        },
      ),
    );
  }

  void _moveToNextItem() {
    final remaining = _remainingItems;

    if (remaining.isEmpty) {
      // كل المنتجات اكتملت
      _showOrderCompleteDialog();
    } else {
      setState(() {
        _currentItemIndex = 0;
        _currentLocationIndex = 0;
        _locationVerified = false;
      });
    }
  }

  /// تخطي المنتج الحالي والانتقال للتالي (بدون إزالته من القائمة)
  void _skipToNextItem() {
    final remaining = _remainingItems;

    if (remaining.length <= 1) {
      // لا يوجد منتج آخر للانتقال إليه
      SnackbarHelper.info(context, 'لا يوجد منتج آخر', floating: true);
      return;
    }

    setState(() {
      // الانتقال للمنتج التالي مع الدوران للبداية إذا وصلنا للنهاية
      _currentItemIndex = (_currentItemIndex + 1) % remaining.length;
      _currentLocationIndex = 0;
      _locationVerified = false;
    });
  }

  void _showOrderCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, color: AppColors.success, size: 32),
            SizedBox(width: 8),
            Text('تم إكمال الطلب!'),
          ],
        ),
        content: const Text(
          'تم تحضير جميع المنتجات بنجاح',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // العودة مع نتيجة النجاح
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsMissing() {
    final item = _currentItem;
    if (item == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.warning),
            SizedBox(width: 8),
            Text('تأكيد'),
          ],
        ),
        content: Text('هل المنتج "${item.productName}" غير موجود في الموقع الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsMissing();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('نعم، غير موجود',style: TextStyle(color: Colors.white  ),),
          ),
        ],
      ),
    );
  }

  void _markAsMissing() {
    final item = _currentItem;
    if (item == null) return;

    // إذا كان هناك موقع آخر، انتقل إليه أولاً
    if (_currentLocationIndex < item.locations.length - 1) {
      setState(() {
        _currentLocationIndex++;
        _locationVerified = false;
      });
      SnackbarHelper.info(
        context,
        'جرب الموقع التالي: ${_currentLocation}',
        floating: true,
      );
      return;
    }

    // لا توجد مواقع أخرى - اعرض دايلوج التأكيد
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            SizedBox(width: 8),
            Text('تحديد كمفقود'),
          ],
        ),
        content: Text('هل تريد تحديد "${item.productName}" كمنتج مفقود؟\n\nتم البحث في جميع المواقع (${item.locations.length})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _missingItems.add(item);
              });
              _moveToNextItem();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
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
    final item = _currentItem;
    final remaining = _remainingItems;
    final completed = _items.where((i) => i.isPicked).toList();

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
                _buildHeaderLocal(remaining.length, completed.length),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('امسح الموقع أولا', style: TextStyle(fontSize: 16)),
                        _buildLocationSection(item),
                        const SizedBox(height: 16),
                        _buildProductCard(item),
                        const SizedBox(height: 16),
                        _buildQuantitySection(item),
                        const SizedBox(height: 24),
                        _buildActions(),
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
  }

  Widget _buildEmptyState() {  
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحضير'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 16),
            const Text(
              'لا توجد منتجات متبقية',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderLocal(int remaining, int completed) {
    final total = remaining + completed + _missingItems.length;
    final done = completed + _missingItems.length;
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
                      'الطلب #${widget.order.orderNumber.substring(0, 8)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$done / $total منتج',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  Widget _buildProductStepper(int remainingCount, int completedCount) {
    final total = remainingCount + completedCount;
    if (total <= 1) return const SizedBox.shrink();
   
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          // شريط الخطوات
          Row(
            children: List.generate(total, (index) {
              final isCompleted = index < completedCount;
              final isCurrent = index == completedCount + _currentItemIndex;

              return Expanded(
                child: Row(
                  children: [
                    // الدائرة
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isCompleted && index >= completedCount) {
                            setState(() {
                              _currentItemIndex = index - completedCount;
                              _currentLocationIndex = 0;
                              _locationVerified = false;
                            });
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: isCurrent ? 32 : 24,
                              height: isCurrent ? 32 : 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? AppColors.success
                                    : isCurrent
                                        ? AppColors.primary
                                        : Colors.grey[300],
                                border: isCurrent
                                    ? Border.all(color: AppColors.primaryWithOpacity(0.3), width: 3)
                                    : null,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isCurrent ? Colors.white : Colors.grey[600],
                                          fontSize: isCurrent ? 14 : 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // الخط الواصل (إلا للعنصر الأخير)
                    if (index < total - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index < completedCount
                              ? AppColors.success
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // نص التقدم
          Text(
            'المنتج ${completedCount + _currentItemIndex + 1} من $total',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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
            height: 130,
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
                // Badge للترتيب
                // Positioned(
                //   top: 12,
                //   right: 12,
                //   child: Container(
                //     padding:
                //         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //     decoration: BoxDecoration(
                //       color: AppColors.primary,
                //       borderRadius: BorderRadius.circular(20),
                //     ),
                //     child: Text(
                //       'المنتج ${_currentItemIndex + 1}',
                //       style: const TextStyle(
                //         color: Colors.white,
                //         fontWeight: FontWeight.bold,
                //         fontSize: 12,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          // اسم المنتج
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'الباركود: ${item.barcode}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(OrderItem item) {
    final color = _locationVerified ? AppColors.success : AppColors.warning;
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
            _locationVerified ? Icons.check_circle : Icons.location_on,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            _currentLocation,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _locationVerified ? AppColors.success : AppColors.textPrimary,
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
                '${_currentLocationIndex + 1}/${item.locations.length}',
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
              'الملتقط',
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
              'المتبقي',
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
              'المطلوب',
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

  Widget _buildScanStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _locationVerified
            ? AppColors.primaryWithOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _locationVerified ? AppColors.primary : Colors.grey[300]!,
          width: 2,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _locationVerified ? Icons.qr_code_scanner : Icons.location_searching,
            size: 48,
            color: _locationVerified ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            _locationVerified
                ? 'جاهز لمسح الباركود'
                : 'امسح باركود الموقع للمتابعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _locationVerified ? AppColors.primary : Colors.grey[600],
            ),
          ),
          if (_locationVerified) ...[
            const SizedBox(height: 8),
            Text(
              'وجه الماسح نحو باركود المنتج',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _confirmMarkAsMissing,
            icon: const Icon(Icons.search_off),
            label: const Text('غير موجود في الموقع'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        // const SizedBox(width: 12),
        // Expanded(
        //   child: OutlinedButton.icon(
        //     onPressed: _skipToNextItem,
        //     icon: const Icon(Icons.skip_next),
        //     label: const Text('تخطي'),
        //     style: OutlinedButton.styleFrom(
        //       foregroundColor: AppColors.pending,
        //       side: const BorderSide(color: AppColors.pending),
        //       padding: const EdgeInsets.symmetric(vertical: 14),
        //     ),
        //   ),
        // ),
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
            print('📷 Scanned: $value');
            // انتظر نهاية السطر أو استخدم delay
            if (value.endsWith('\n') || value.endsWith('\r')) {
              final barcode = value.trim();
              if (barcode.isNotEmpty) {
                _processScan(barcode);
              }
              _scanController.clear();
            } else {
              // بعض الماسحات لا ترسل newline - استخدم delay
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    // إغلاق تلقائي بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
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
              const Text(
                'تم الإكمال! 🎉',
                style: TextStyle(
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
