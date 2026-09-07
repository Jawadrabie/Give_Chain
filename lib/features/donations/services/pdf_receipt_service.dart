import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/api_enums.dart';
import '../data/donation_models.dart';

abstract final class PdfReceiptService {
  static Future<void> exportAndPrintReceipt(DonationResponse donation) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final ttf = pw.Font.ttf(fontData);

    final amountText = donation.acceptedAmount != null
        ? '${NumberFormat('#,##0.##').format(donation.acceptedAmount)} (تم قبول المبلغ)'
        : donation.amount != null
            ? NumberFormat('#,##0.##').format(donation.amount)
            : (donation.itemName.isNotEmpty
                ? '${donation.itemName} (${donation.quantity ?? 1} ${donation.unit == null ? '' : ApiEnums.unit[donation.unit] ?? ''})'
                : donation.serviceDescription);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'منصة GiveChain للعمل الخيري',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'إيصال توثيق تبرع رسمي',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://givechain.runasp.net/donations/${donation.id}',
                      width: 60,
                      height: 60,
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.teal300),
                pw.SizedBox(height: 16),

                // Details Grid
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _row(ttf, 'رقم العملية (Reference ID):', donation.id),
                      _row(
                        ttf,
                        'تاريخ التبرع:',
                        DateFormat('yyyy-MM-dd HH:mm').format(donation.donationDate.toLocal()),
                      ),
                      _row(ttf, 'الجهة المستفيدة / الهدف:', donation.targetName),
                      _row(ttf, 'نوع التبرع:', donation.typeLabel),
                      _row(
                        ttf,
                        'طريقة الدفع والتسليم:',
                        donation.paymentMethodLabel.isNotEmpty
                            ? donation.paymentMethodLabel
                            : 'تسليم مباشر',
                      ),
                      _row(ttf, 'قيمة العطاء المقبولة:', amountText),
                      _row(ttf, 'حالة العملية:', donation.statusLabel),
                    ],
                  ),
                ),

                if (donation.verificationNotes.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'ملاحظات التوثيق والإدارة:',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    donation.verificationNotes,
                    style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.grey800),
                  ),
                ],

                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'شكراً لعطائك الموثوق عبر GiveChain ❤️',
                      style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.teal800),
                    ),
                    pw.Text(
                      'صادر من تطبيق الهاتف بتاريخ: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'GiveChain_Receipt_${donation.id.substring(0, 8)}.pdf',
    );
  }

  static pw.Widget _row(pw.Font font, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
