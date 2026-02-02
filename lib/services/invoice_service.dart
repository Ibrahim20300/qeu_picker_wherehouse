import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class InvoiceService {
  static Future<void> generateAndPrintInvoice(OrderModel order) async {
    final pdf = await _generatePdf(order);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
      
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('P12',style: pw.TextStyle(fontSize: 200)),
              // Header
              _buildHeader(order, arabicFontBold),
              pw.SizedBox(height: 20),

              // Order Info
              _buildOrderInfo(order, arabicFont, arabicFontBold),
              pw.SizedBox(height: 20),

              // Products Table
              _buildProductsTable(order, arabicFont, arabicFontBold),
              pw.SizedBox(height: 20),

              // Summary
              _buildSummary(order, arabicFont, arabicFontBold),

              pw.Spacer(),

              // Footer
              _buildFooter(arabicFont),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(OrderModel order, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue800,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'فاتورة الطلب',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 28,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            order.orderNumber,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 20,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOrderInfo(OrderModel order, pw.Font font, pw.Font fontBold) {
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm', 'ar');

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تاريخ الإنشاء',
                style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                dateFormat.format(order.createdAt),
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'الحالة',
                style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                order.statusDisplayName,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: order.status == OrderStatus.completed ? PdfColors.green : PdfColors.orange,
                ),
              ),
            ],
          ),
          if (order.bagsCount > 0)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'عدد الأكياس',
                  style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
                ),
                pw.Text(
                  '${order.bagsCount}',
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductsTable(OrderModel order, pw.Font font, pw.Font fontBold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('#', fontBold, isHeader: true),
            _buildTableCell('المنتج', fontBold, isHeader: true),
            _buildTableCell('الباركود', fontBold, isHeader: true),
            _buildTableCell('الكمية المطلوبة', fontBold, isHeader: true),
            _buildTableCell('الكمية الملتقطة', fontBold, isHeader: true),
          ],
        ),
        // Data Rows
        ...order.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              _buildTableCell('${index + 1}', font),
              _buildTableCell(item.productName, font),
              _buildTableCell(item.barcode, font),
              _buildTableCell('${item.requiredQuantity}', font),
              _buildTableCell(
                '${item.pickedQuantity}',
                font,
                color: item.isPicked ? PdfColors.green : PdfColors.orange,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildSummary(OrderModel order, pw.Font font, pw.Font fontBold) {
    final completedItems = order.items.where((item) => item.isPicked).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('إجمالي المنتجات', '${order.totalItems}', font, fontBold),
          _buildSummaryItem('المنتجات المكتملة', '$completedItems', font, fontBold, color: PdfColors.green),
          _buildSummaryItem('المنتجات المتبقية', '${order.totalItems - completedItems}', font, fontBold, color: PdfColors.orange),
          if (order.bagsCount > 0)
            _buildSummaryItem('الأكياس', '${order.bagsCount}', font, fontBold, color: PdfColors.blue),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, pw.Font font, pw.Font fontBold, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontBold, fontSize: 18, color: color ?? PdfColors.black),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font font) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm:ss', 'ar');

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'QEU Picker App',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500),
          ),
          pw.Text(
            'تم الطباعة: ${dateFormat.format(now)}',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }
}
