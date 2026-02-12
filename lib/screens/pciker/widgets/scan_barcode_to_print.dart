import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import '../../../l10n/app_localizations.dart';
import '../../../constants/app_colors.dart';

class ScanBarcodeToPrintScreen extends StatelessWidget {
  final Map<String, dynamic> task;

  const ScanBarcodeToPrintScreen({super.key, required this.task});

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

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
    final barcodeData = orderNumber.isNotEmpty ? '$orderNumber' : task['id'].toString();

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
                        ? 'توجه إلى الطابعة لطباعة البوليصة'
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
                      // Barcode
                      bw.BarcodeWidget(
                        barcode: bw.Barcode.code128(),
                        data: barcodeData.replaceAll('#', ''),
                        width: 220,
                        height: 60,
                        drawText: true,
                        style: const TextStyle(fontSize: 10),
                      ),
                      const Divider(thickness: 1),
                      const SizedBox(height: 4),

                      _buildRow(S.isAr ? 'الترتيب' : 'Position', position.isNotEmpty ? 'P$position' : '-'),
                      _buildRow(S.isAr ? 'رقم الطلب' : 'Order', orderNumber.replaceAll('#', ' ')),
                      _buildRow(S.isAr ? 'الحي' : 'District', district),
                      _buildRow(S.isAr ? 'الوقت' : 'Time', slotTime),
                      _buildRow(S.isAr ? 'التاريخ' : 'Date', slotDate),
                      _buildRow(S.isAr ? 'المنطقة' : 'Zone', zone),
                      _buildRow(S.isAr ? 'عدد المناطق' : 'Total Zones', totalZone),

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
