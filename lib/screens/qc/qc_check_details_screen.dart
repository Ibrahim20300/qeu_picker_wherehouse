import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/qc_check_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/qc_provider.dart';

enum ZoneStatus { none, complete, problem }

class QCCheckDetailsScreen extends StatefulWidget {
  final QCCheckModel check;
  final String? initialZoneCode;

  const QCCheckDetailsScreen({super.key, required this.check, this.initialZoneCode});

  @override
  State<QCCheckDetailsScreen> createState() => _QCCheckDetailsScreenState();
}

class _QCCheckDetailsScreenState extends State<QCCheckDetailsScreen> {
  late List<ZoneStatus> _zoneStatuses;
  late List<String?> _zoneRejectionReasons;

  final _scanController = TextEditingController();
  final _scanFocusNode = FocusNode();
  Timer? _focusTimer;
  final _scrollController = ScrollController();
  final List<GlobalKey> _zoneKeys = [];

  final List<String> _rejectionReasons = [
    'منتج مفقود',
    'منتج تالف',
  ];

  @override
  void initState() {
    super.initState();
    _zoneStatuses = List.filled(widget.check.zoneTasks.length, ZoneStatus.none);
    _zoneRejectionReasons = List.filled(widget.check.zoneTasks.length, null);
    _zoneKeys.addAll(List.generate(widget.check.zoneTasks.length, (_) => GlobalKey()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupScanning();
      // Handle initial zone code from barcode scan
      if (widget.initialZoneCode != null) {
        _handleZoneScan(widget.initialZoneCode!);
      }
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
    // Parse format: orderNumber-zoneCode (e.g. 2015750277038653267-Z01)
    String? orderPart;
    String zonePart = scannedValue;

    if (scannedValue.contains('-')) {
      final lastDash = scannedValue.lastIndexOf('-');
      orderPart = scannedValue.substring(0, lastDash);
      zonePart = scannedValue.substring(lastDash + 1);
    }

    // Verify order number matches this check
    if (orderPart != null) {
      final checkOrder = widget.check.orderNumber;
      if (checkOrder != orderPart && !checkOrder.contains(orderPart) && !orderPart.contains(checkOrder)) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رقم الطلب غير متطابق: $orderPart'),
            backgroundColor: AppColors.error,
          ),
        );
        _requestFocus();
        return;
      }
    }

    _handleZoneScan(zonePart);
    _requestFocus();
  }

  void _handleZoneScan(String zoneCode) {
    final code = zoneCode.toUpperCase().trim();
    final index = widget.check.zoneTasks.indexWhere((z) {
      final zc = z.zoneCode.toUpperCase();
      // Exact match: Z01 == Z01
      if (zc == code) return true;
      // Zone ends with scanned code: Z01 ends with 01, Z03 ends with 03
      if (zc.endsWith(code)) return true;
      // Scanned code ends with zone's numeric part: 03 matches Z03
      final zoneDigits = zc.replaceAll(RegExp(r'[^0-9]'), '');
      final scanDigits = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (zoneDigits.isNotEmpty && scanDigits.isNotEmpty && zoneDigits == scanDigits) return true;
      return false;
    });

    if (index == -1) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على منطقة: $zoneCode'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Scroll to the zone card
    final keyContext = _zoneKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(keyContext, duration: const Duration(milliseconds: 300), alignment: 0.3);
    }

    // Show dialog to choose مكتمل or يوجد مشكلة
    _showZoneScanDialog(index);
  }

  void _showZoneScanDialog(int index) {
    final zone = widget.check.zoneTasks[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          children: [
                   Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${zone.packageCount} كيس',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            SizedBox(height: 20,),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      zone.zoneCode,
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Center(
                    child: Text('منطقة ${zone.zoneCode}', style: const TextStyle(fontSize: 16)),
                  ),
                   
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مكتمل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _zoneStatuses[index] = ZoneStatus.complete;
                    _zoneRejectionReasons[index] = null;
                  });
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('مكتمل', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('أو اختر سبب المشكلة:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            // Rejection reasons
            ..._rejectionReasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _zoneStatuses[index] = ZoneStatus.problem;
                      _zoneRejectionReasons[index] = reason;
                    });
                  },
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: Text(reason, style: const TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _scanController.removeListener(_onScanInput);
    _scanController.dispose();
    _scanFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get completedCount => _zoneStatuses.where((s) => s == ZoneStatus.complete).length;
  int get problemCount => _zoneStatuses.where((s) => s == ZoneStatus.problem).length;
  bool get allDecided => _zoneStatuses.every((s) => s != ZoneStatus.none);
  bool get allComplete => _zoneStatuses.every((s) => s == ZoneStatus.complete);
  bool get hasProblems => _zoneStatuses.any((s) => s == ZoneStatus.problem);
  bool get allProblemsHaveReasons {
    for (int i = 0; i < _zoneStatuses.length; i++) {
      if (_zoneStatuses[i] == ZoneStatus.problem && _zoneRejectionReasons[i] == null) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'فحص #${check.orderNumber.length > 6 ? check.orderNumber.substring(check.orderNumber.length - 6) : check.orderNumber}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
          children: [
            // Order info header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'P${check.queuePosition}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text(
                          //   check.customerName,
                          //   style: const TextStyle(
                          //     fontSize: 18,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                          const SizedBox(height: 2),
                          Text(
                            '#${check.orderNumber}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _statusColor(check.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          check.status.displayName,
                          style: TextStyle(
                            color: _statusColor(check.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    children: [
                      _buildHeaderStat(
                        Icons.shopping_bag_outlined,
                        '${check.expectedPackageCount}',
                        'أكياس متوقعة',
                        AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderStat(
                        Icons.map_outlined,
                        '${check.zoneTasks.length}',
                        'مناطق',
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderStat(
                        Icons.inventory_2_outlined,
                        '${check.totalZonePicked}/${check.totalZoneItems}',
                        'منتجات',
                        AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        
            const SizedBox(height: 8),
        
            // Section title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  const Text(
                    'المناطق',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (completedCount > 0)
                    _buildMiniChip('$completedCount مكتمل', AppColors.success),
                  if (problemCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildMiniChip('$problemCount مشكلة', AppColors.error),
                  ],
                ],
              ),
            ),
        
            // Zone tasks list
            ListView.separated(
              controller: ScrollController(),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: check.zoneTasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final zone = check.zoneTasks[index];
                return Container(
                  key: _zoneKeys[index],
                  child: _buildZoneCard(zone, index),
                );
              },
            ),
        
            // Bottom bar
            _buildBottomBar(check),
          ],
        ),
      ),
      _buildHiddenScanField(),
      ],
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

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _buildBottomBar(QCCheckModel check) {
    final qcProvider = context.watch<QCProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: check.zoneTasks.isEmpty
                    ? 0
                    : (completedCount + problemCount) / check.zoneTasks.length,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  allComplete ? AppColors.success : hasProblems ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              allDecided
                  ? (allComplete ? 'تم فحص جميع المناطق بنجاح' : 'تم تحديد حالة جميع المناطق')
                  : '${completedCount + problemCount} من ${check.zoneTasks.length} مناطق تم فحصها',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: allComplete ? AppColors.success : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // يوجد مشكلة
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (allDecided && hasProblems && allProblemsHaveReasons && !qcProvider.verifyLoading)
                        ? () => _onReject(check)
                        : null,
                    icon: qcProvider.verifyLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.warning_amber_rounded),
                    label: const Text('يوجد مشكلة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: (allDecided && hasProblems && allProblemsHaveReasons) ? AppColors.error : Colors.grey[300]!,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // الطلب مكتمل
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (allComplete && !qcProvider.verifyLoading)
                        ? () => _onApprove(check)
                        : null,
                    icon: qcProvider.verifyLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                    label: const Text('الطلب مكتمل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  void _onApprove(QCCheckModel check) async {
    final qcProvider = context.read<QCProvider>();
    final authProvider = context.read<AuthProvider>();
    qcProvider.init(authProvider.apiService);

    final success = await qcProvider.approveCheck(check.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد الطلب بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      qcProvider.loadChecks();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qcProvider.verifyError ?? 'فشل اعتماد الفحص'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onReject(QCCheckModel check) async {
    // Build rejected_zones array from zones with problems
    final rejectedZones = <Map<String, String>>[];
    final reasonSummaries = <String>[];
    for (int i = 0; i < _zoneStatuses.length; i++) {
      if (_zoneStatuses[i] == ZoneStatus.problem && _zoneRejectionReasons[i] != null) {
        final zone = check.zoneTasks[i];
        rejectedZones.add({
          'zone_code': zone.zoneCode,
          'reason': _zoneRejectionReasons[i]!,
        });
        reasonSummaries.add('${zone.zoneCode}: ${_zoneRejectionReasons[i]}');
      }
    }

    final rejectionReason = reasonSummaries.join(' | ');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('تأكيد رفض الطلب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المناطق المرفوضة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...reasonSummaries.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final qcProvider = context.read<QCProvider>();
    final authProvider = context.read<AuthProvider>();
    qcProvider.init(authProvider.apiService);

    final success = await qcProvider.rejectCheck(
      check.id,
      rejectionReason: rejectionReason,
      rejectedZones: rejectedZones,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الطلب'),
          backgroundColor: AppColors.error,
        ),
      );
      qcProvider.loadChecks();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qcProvider.verifyError ?? 'فشل رفض الفحص'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildHeaderStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(QCZoneTask zone, int index) {
    final status = _zoneStatuses[index];
    final isComplete = status == ZoneStatus.complete;
    final isProblem = status == ZoneStatus.problem;

    Color borderColor;
    Color? bgColor;
    if (isComplete) {
      borderColor = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.04);
    } else if (isProblem) {
      borderColor = AppColors.error;
      bgColor = AppColors.error.withValues(alpha: 0.04);
    } else {
      borderColor = Colors.grey.withValues(alpha: 0.15);
      bgColor = Colors.white;
    }

    return Card(
      elevation: (isComplete || isProblem) ? 0 : 1,
      margin: EdgeInsets.zero,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: (isComplete || isProblem) ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Zone info row
            Row(
              children: [
                // Zone code
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.success.withValues(alpha: 0.1)
                        : isProblem
                            ? AppColors.error.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    zone.zoneCode,
                    style: TextStyle(
                      color: isComplete
                          ? AppColors.success
                          : isProblem
                              ? AppColors.error
                              : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المحضر',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        zone.pickerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${zone.pickedItems}/${zone.totalItems} منتج',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (zone.exceptionItems > 0) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              '${zone.exceptionItems}',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Package count
                Container(
                  width: 64,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          '${zone.packageCount}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const Text(
                        'كيس',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons row
            // Row(
            //   children: [
            //     // مكتمل button
            //     Expanded(
            //       child: _buildZoneActionButton(
            //         icon: Icons.check_circle,
            //         label: 'مكتمل',
            //         isSelected: isComplete,
            //         color: AppColors.success,
            //         onTap: () {
            //           setState(() {
            //             _zoneStatuses[index] = isComplete ? ZoneStatus.none : ZoneStatus.complete;
            //             if (_zoneStatuses[index] != ZoneStatus.problem) {
            //               _zoneRejectionReasons[index] = null;
            //             }
            //           });
            //         },
            //       ),
            //     ),
            //     const SizedBox(width: 10),
            //     // يوجد مشكلة button
            //     Expanded(
            //       child: _buildZoneActionButton(
            //         icon: Icons.warning_amber_rounded,
            //         label: 'يوجد مشكلة',
            //         isSelected: isProblem,
            //         color: AppColors.error,
            //         onTap: () {
            //           setState(() {
            //             if (isProblem) {
            //               _zoneStatuses[index] = ZoneStatus.none;
            //               _zoneRejectionReasons[index] = null;
            //             } else {
            //               _zoneStatuses[index] = ZoneStatus.problem;
            //             }
            //           });
            //         },
            //       ),
            //     ),
            //   ],
            // ),

            // Rejection reason options (shown when problem is selected)
            if (isProblem) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سبب المشكلة:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _rejectionReasons.map((reason) {
                        final isSelected = _zoneRejectionReasons[index] == reason;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _zoneRejectionReasons[index] = isSelected ? null : reason;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.error.withValues(alpha: 0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.error : Colors.grey[300]!,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  size: 16,
                                  color: isSelected ? AppColors.error : Colors.grey[400],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.error : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildZoneActionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(QCStatus status) {
    switch (status) {
      case QCStatus.pending:
        return Colors.orange;
      case QCStatus.inProgress:
        return AppColors.primary;
      case QCStatus.passed:
        return AppColors.success;
      case QCStatus.failed:
        return AppColors.error;
      case QCStatus.overridden:
        return Colors.purple;
      case QCStatus.unspecified:
        return Colors.grey;
    }
  }
}
