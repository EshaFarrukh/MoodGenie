import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class MoodReportGenerator {
  /// Generates and returns the path to a PDF report for the user's mood data.
  static Future<String> generatePdf({
    required String userName,
    required DateTime startDate,
    required DateTime endDate,
    required double avgScore,
    required int totalLogs,
    required int streak,
    required Map<String, int> moodCounts,
    required List<Map<String, dynamic>> allEntries,
  }) async {
    final pdf = pw.Document();

    // Calculate percentages
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Page 1: Summary Dashboard
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
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
                        'MoodGenie Analytics Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#002B5B'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Prepared for $userName',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColor.fromHex('#6D6689'),
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#002B5B'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // KPI Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildKpiCard(
                    'Average Score',
                    '${avgScore.toStringAsFixed(1)} / 10',
                  ),
                  _buildKpiCard('Total Logs', '$totalLogs'),
                  _buildKpiCard('Highest Streak', '$streak Days'),
                ],
              ),
              pw.SizedBox(height: 30),

              // Mood Distribution
              pw.Text(
                'Mood Distribution Overview',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#002B5B'),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F9FA'),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('#E9ECEF')),
                ),
                child: pw.Column(
                  children: sortedMoods.map((entry) {
                    final moodName = entry.key;
                    final percentage = (entry.value / totalLogs * 100).round();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 100,
                            child: pw.Text(
                              moodName.toUpperCase(),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Stack(
                              children: [
                                pw.Container(
                                  height: 10,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#E9ECEF'),
                                    borderRadius: pw.BorderRadius.circular(5),
                                  ),
                                ),
                                pw.Container(
                                  height: 10,
                                  width:
                                      (percentage / 100) * 350, // rough scale
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#5A4B9C'),
                                    borderRadius: pw.BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text('$percentage% (${entry.value} logs)'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Note: Standard generated report from MoodGenie device.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColor.fromHex('#ADB5BD'),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Page 2: Detailed Entries Log
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final sortedEntries = List<Map<String, dynamic>>.from(allEntries)
            ..sort(
              (a, b) =>
                  (b['date'] as DateTime).compareTo(a['date'] as DateTime),
            );

          return [
            pw.Text(
              'Detailed Mood Log',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#002B5B'),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#5A4B9C'),
                    width: 2,
                  ),
                ),
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#5A4B9C'),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              headers: ['Date', 'Mood', 'Intensity', 'Notes'],
              data: sortedEntries.map((e) {
                final date = e['date'] as DateTime;
                final mood = e['mood'] as String;
                final intensity = e['intensity'] as double;
                final note = e['note'] as String? ?? '';

                return [
                  _formatDate(date),
                  mood.toUpperCase(),
                  '$intensity/10',
                  note.isEmpty ? '-' : note,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    // Save PDF
    final output = await getApplicationDocumentsDirectory();
    final file = File(
      '${output.path}/MoodGenie_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  static pw.Widget _buildKpiCard(String title, String value) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F9FA'),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromHex('#E9ECEF')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColor.fromHex('#6D6689'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#002B5B'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
