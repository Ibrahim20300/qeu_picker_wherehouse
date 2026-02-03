import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class InvoiceService {
  // مقاس الملصق الثابت
  static const _labelFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
    120 * PdfPageFormat.mm,
    marginAll: 4 * PdfPageFormat.mm,
  );

  static Future<void> generateAndPrintInvoice(OrderModel order) async {
    final pdf = await _generatePdf(order);
    final bytes = await pdf.save();

    // استخدام نافذة الطباعة مع المقاس المحدد
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      format: _labelFormat,
      name: 'Label_${order.orderNumber}',
    );
  }

  static Future<void> generateAndShareInvoice(OrderModel order) async {
    final pdf = await _generatePdf(order);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_${order.orderNumber}.pdf',
    );
  }

  static Future<File> generateAndSaveInvoice(OrderModel order) async {
    final pdf = await _generatePdf(order);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice_${order.orderNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<pw.Document> _generatePdf(OrderModel order) async {
    final pdf = pw.Document();

    // استخدام خطوط محلية بدلاً من تحميلها من الإنترنت
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: _labelFormat,
        textDirection: pw.TextDirection.ltr,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Position - كبير في الأعلى
              pw.Center(
                child: pw.Text(
                  order.position ?? '-',
                  style: pw.TextStyle(font: fontBold, fontSize: 45),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 5),

              // Order-Zone - مدمج
      

              // Barcode - الباركود
              pw.Center(
                child: pw.BarcodeWidget(
                  margin: pw.EdgeInsets.only(top: 0,bottom: 0),
                  barcode: pw.Barcode.code128(),
                  data: order.orderNumber+'-'+order.zone!,
                  width: 55 * PdfPageFormat.mm,
                  height: 25,
                  drawText: true,
                  textStyle: pw.TextStyle(font: font, fontSize: 8),
                  textPadding: 2
                ),
              ),
              pw.Divider(thickness: 0.8, color: PdfColors.black),

              // Neighborhood - الحي
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'District: ',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                    pw.Text(
                      order.neighborhood ?? '-',
                      style: pw.TextStyle(font: fontBold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Slot Time & Date - صف واحد
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  // Slot Time
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Time',
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                          pw.Text(
                            order.slotTime ?? '-',
                            style: pw.TextStyle(font: fontBold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Container(width: 1, height: 20, color: PdfColors.black),
                  // Slot Date
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Date',
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                          pw.Text(
                            order.slotDate ?? '-',
                            style: pw.TextStyle(font: fontBold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  // Zone
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 4),
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'From Zone',
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                          pw.Text(
                            order.zone ?? '-',
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Total Zone
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(left: 4),
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Total Zones',
                            style: pw.TextStyle(font: font, fontSize: 7),
                          ),
                          pw.Text(
                            order.totalZone.toString(),
                            style: pw.TextStyle(font: fontBold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
   
              // pw.SizedBox(height: 6),

              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    dateFormat.format(DateTime.now()),
                    style: pw.TextStyle(font: font, fontSize: 7),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildProductsTable(
    OrderModel order,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header Row
        pw.TableRow(
          children: [
            _buildTableCell('#', fontBold, isHeader: true),
            _buildTableCell('المنتج', fontBold, isHeader: true),
            _buildTableCell('الباركود', fontBold, isHeader: true),
            _buildTableCell('الكمية', fontBold, isHeader: true),
          ],
        ),
        // Data Rows
        ...order.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}', font),
              _buildTableCell(item.productName, font),
              _buildTableCell(item.barcode, font),
              _buildTableCell('${item.requiredQuantity}', font),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
