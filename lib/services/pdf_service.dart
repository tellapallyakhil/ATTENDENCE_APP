import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/student.dart';

class PdfService {
  static Future<void> generateAbsenteesPdf({
    required String subject,
    required String date,
    required List<Student> absentees,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Absentees Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Subject: $subject'),
              pw.Text('Date: $date'),
              pw.SizedBox(height: 15),

              pw.Table.fromTextArray(
                headers: ['S.No', 'Register No', 'Name'],
                data: List.generate(
                  absentees.length,
                  (index) => [
                    (index + 1).toString(),
                    absentees[index].regNo,
                    absentees[index].name,
                  ],
                ),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/Absentees_${subject}_$date.pdf',
    );

    await file.writeAsBytes(await pdf.save());
  }
}
