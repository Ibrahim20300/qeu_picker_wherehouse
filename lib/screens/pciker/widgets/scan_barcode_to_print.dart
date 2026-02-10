import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import '../../../l10n/app_localizations.dart';
import '../../../constants/app_colors.dart';

class ScanBarcodeToPrintScreen extends StatelessWidget {
  final Map<String, dynamic> task;

  const ScanBarcodeToPrintScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final orderNumber = task['order_number']?.toString() ?? '';
    final items = task['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
    final zone = task['zone_name']?.toString()
        ?? firstItem?['zone']?.toString()
        ?? '-';
    final position = task['queue_position']?.toString() ?? '';
    final district = task['district']?.toString()
        ?? task['neighborhood']?.toString()
        ?? '-';
    final slotTime = task['slot_time']?.toString() ?? '-';
    final totalZone = task['total_zones']?.toString() ?? '-';
    final barcodeData = orderNumber.isNotEmpty ? '$orderNumber-$zone' : task['id'].toString();

    String slotDate = '-';
    final createdAt = task['created_at']?.toString() ?? '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        slotDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(S.print_),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // رسالة التوجيه للطابعة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.warning.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.print, color: AppColors.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.isAr
                        ? 'توجه إلى الطابعة لطباعة هذه البوليصة'
                        : 'Go to the printer to print this label',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // معاينة البوليصة
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Position
                      if (position.isNotEmpty)
                        Text(
                          'P$position',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const Divider(thickness: 1),
                      const SizedBox(height: 8),

                      // Barcode
                      bw.BarcodeWidget(
                        barcode: bw.Barcode.code128(),
                        data: barcodeData,
                        width: 220,
                        height: 60,
                        drawText: true,
                        style: const TextStyle(fontSize: 10),
                      ),
                      const Divider(thickness: 0.8),
                      const SizedBox(height: 4),

                      // District
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('District: ', style: TextStyle(fontSize: 12)),
                          Text(
                            district,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time & Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('Time', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                const SizedBox(height: 2),
                                Text(slotTime, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 35, color: Colors.grey.shade400),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                const SizedBox(height: 2),
                                Text(slotDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Zone & Total Zones
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  Text('From Zone', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  Text(zone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  Text('Total Zones', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  Text(totalZone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Order Number
                      Text(
                        orderNumber.replaceAll('#', ' '),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 0.5),
                      Builder(builder: (_) {
                        final now = DateTime.now();
                        return Text(
                          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // زر "قمت بالطباعة"
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(S.confirm),
                      content: Text(
                        S.isAr
                            ? 'هل انت متأكد ان قمت بطباعة البوليصة؟'
                            : 'Are you sure you have printed the label?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(S.cancel),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(S.confirm),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  S.isAr ? 'قمت بالطباعة' : 'I have printed',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
