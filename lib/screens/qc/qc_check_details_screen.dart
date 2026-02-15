import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/qc_check_model.dart';
import '../../models/order_model.dart';
import '../../l10n/app_localizations.dart';
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

  List<String> get _rejectionReasons => [S.missingBag, S.extraBag];

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
            content: Text(S.orderNumberMismatch(orderPart)),
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
          content: Text(S.zoneNotFound(zoneCode)),
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
                '${zone.packageCount} ${S.bag}',
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
                    child: Text(S.zoneLabel(zone.zoneCode), style: const TextStyle(fontSize: 16)),
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
                label: Text(S.statusCompleted, style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(S.orChooseProblemReason, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
          S.checkNum(check.orderNumber.length > 6 ? check.orderNumber.substring(check.orderNumber.length - 6) : check.orderNumber),
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
                      Spacer(),
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
                        S.expectedBags,
                        AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderStat(
                        Icons.map_outlined,
                        '${check.zoneTasks.length}',
                        S.zones,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderStat(
                        Icons.inventory_2_outlined,
                        '${check.totalZonePicked}/${check.totalZoneItems}',
                        S.productsLabel,
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
                  Text(
                    S.zonesLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (completedCount > 0)
                    _buildMiniChip(S.completedCount(completedCount), AppColors.success),
                  if (problemCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildMiniChip(S.problemCount(problemCount), AppColors.error),
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
                  ? (allComplete ? S.allZonesInspectedSuccess : S.allZoneStatusesDetermined)
                  : S.zonesInspected(completedCount + problemCount, check.zoneTasks.length),
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
                    label: Text(S.hasProblem),
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
                    label: Text(S.orderComplete),
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
        SnackBar(
          content: Text(S.orderApprovedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      qcProvider.loadChecks();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qcProvider.verifyError ?? S.failedToApproveInspection),
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(S.confirmOrderRejection),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.rejectedZones,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(S.confirmRejection),
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
        SnackBar(
          content: Text(S.orderRejected),
          backgroundColor: AppColors.error,
        ),
      );
      qcProvider.loadChecks();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qcProvider.verifyError ?? S.failedToRejectInspection),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showOrderVerificationDialog(index),
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
                        S.preparer,
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
                            '${zone.pickedItems}/${zone.totalItems} ${S.product}',
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
                      Text(
                        S.bag,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // View products button
            if (zone.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showItemsBottomSheet(zone),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text('${S.productsLabel} (${zone.items.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

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
                    Text(
                      S.problemReason,
                      style: const TextStyle(
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
      ),
    );
  }

  void _showOrderVerificationDialog(int index) {
    _focusTimer?.cancel();
    _focusTimer = null;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.verifyOrderNumber, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.enterLast6Digits,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: S.last6Digits,
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.receipt_long),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                _verifyAndProceed(ctx, controller.text.trim(), index);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              _verifyAndProceed(ctx, controller.text.trim(), index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(S.confirm),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) _setupScanning();
    });
  }

  void _verifyAndProceed(BuildContext ctx, String enteredOrder, int index) {
    if (enteredOrder.isEmpty) return;

    final checkOrder = widget.check.orderNumber.replaceAll('#', '');
    final lastSix = checkOrder.length >= 6 ? checkOrder.substring(checkOrder.length - 6) : checkOrder;
    if (enteredOrder == lastSix) {
      Navigator.pop(ctx);
      _showZoneScanDialog(index);
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.orderNumberMismatchSimple),
          backgroundColor: AppColors.error,
        ),
      );
    }
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

  void _showItemsBottomSheet(QCZoneTask zone) {
    _focusTimer?.cancel();
    _focusTimer = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        zone.zoneCode,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${S.productsLabel} (${zone.items.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Items list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: zone.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _buildItemCard(zone.items[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _setupScanning();
    });
  }

  Widget _buildItemCard(OrderItem item) {
    final isOutOfStock = item.status == 'ITEM_OUT_OF_STOCK';
    final isPicked = item.status == 'ITEM_PICKED';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? AppColors.error.withValues(alpha: 0.04)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? AppColors.error.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 56,
                    height: 56,
                
                    placeholder: (_, _) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 10),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      item.primaryLocation,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Quantity
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPicked
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.pickedQuantity}/${item.requiredQuantity} ${item.unitName ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPicked ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                    if (isOutOfStock) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'غير متوفر',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Price
                    Text(
                      '${item.unitPrice} ر.س',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
