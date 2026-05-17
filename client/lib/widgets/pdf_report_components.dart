import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/entity_details.dart';
import '../utils/formatters.dart';

class PdfReportComponents {
  static pw.Widget entityHeader(EntityDetails? entity) {
    if (entity == null) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(entity.name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text(
          'ABN: ${Formatters.formatAbn(entity.abn)}  |  ${entity.incorporationIdentifier}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  static pw.Widget pageFooter(pw.Context ctx, String generatedDate) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated $generatedDate',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
        ],
      ),
    );
  }
}
