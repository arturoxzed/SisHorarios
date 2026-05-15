import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PdfExportService {
  // ─── Public API ──────────────────────────────────────────────────────────

  /// Exports a section schedule and saves it to the Downloads folder.
  /// Returns the path of the saved file, or null on failure.
  Future<String?> exportSectionSchedule({
    required SectionSchedule schedule,
    required Section section,
    required Grade grade,
    required List<Subject> subjects,
    required List<Teacher> teachers,
  }) async {
    final pdf = pw.Document();
    final font     = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final config   = grade.config;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Horario: ${section.name} — ${grade.name}',
              style: pw.TextStyle(font: fontBold, fontSize: 16),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generado: ${_fmtDate(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            _buildTable(
              config: config,
              labelPrefix: 'S',
              dayHeaders: config.classDays,
              cellBuilder: (day, p) {
                final slot = schedule.getSlot(day, p);
                if (slot == null) return null;
                return _CellData(
                  top: _subjectName(subjects, slot.subjectId),
                  bottom: _teacherName(teachers, slot.teacherId),
                  color: _subjectPdfColor(subjects, slot.subjectId),
                );
              },
              font: font,
              fontBold: fontBold,
            ),
          ],
        ),
      ),
    );

    final filename =
        'horario_${section.name}_${grade.name}_${_fileDate()}.pdf';
    return _savePdf(pdf, filename);
  }

  /// Exports a teacher's schedule across all sections.
  Future<String?> exportTeacherSchedule({
    required Teacher teacher,
    required List<SectionSchedule> allSchedules,
    required List<Grade> grades,
    required List<Section> sections,
    required List<Subject> subjects,
  }) async {
    final pdf = pw.Document();
    final font     = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Use the first available grade config (covers the common case).
    final config = grades.isNotEmpty ? grades.first.config : const GradeConfig();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Horario Maestro: ${teacher.fullName}',
                style: pw.TextStyle(font: fontBold, fontSize: 16)),
            pw.SizedBox(height: 12),
            _buildTable(
              config: config,
              labelPrefix: 'S',
              dayHeaders: config.classDays,
              cellBuilder: (day, p) {
                for (final sched in allSchedules) {
                  final slot = sched.getSlot(day, p);
                  if (slot == null || slot.teacherId != teacher.id) continue;
                  Section? sec;
                  try {
                    sec = sections.firstWhere((s) => s.id == sched.sectionId);
                  } catch (_) {}
                  return _CellData(
                    top: _subjectName(subjects, slot.subjectId),
                    bottom: sec?.name ?? '?',
                    color: _subjectPdfColor(subjects, slot.subjectId),
                  );
                }
                return null;
              },
              font: font,
              fontBold: fontBold,
            ),
          ],
        ),
      ),
    );

    final filename = 'horario_maestro_${teacher.fullName}_${_fileDate()}.pdf'
        .replaceAll(' ', '_');
    return _savePdf(pdf, filename);
  }

  // ─── PDF table builder ───────────────────────────────────────────────────

  pw.Widget _buildTable({
    required GradeConfig config,
    required String labelPrefix,
    required List<String> dayHeaders,
    required _CellData? Function(String day, int period) cellBuilder,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    final labels = config.sessionLabels;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            _pdfCell('Hora / Sesión', fontBold, isHeader: true),
            ...dayHeaders.map((d) => _pdfCell(d, fontBold, isHeader: true)),
          ],
        ),
        // Session rows
        ...List.generate(config.sessionsPerDay, (p) {
          return pw.TableRow(
            children: [
              _pdfCell('$labelPrefix${p + 1}  ${labels[p]}', fontBold, small: true),
              ...dayHeaders.map((day) {
                final data = cellBuilder(day, p);
                if (data == null) return _pdfCell('—', font, small: true);
                return pw.Container(
                  color: data.color,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(data.top,
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 7, color: PdfColors.white)),
                      pw.Text(data.bottom,
                          style: pw.TextStyle(font: font, fontSize: 6)),
                    ],
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfCell(String text, pw.Font font,
      {bool isHeader = false, bool small = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: small ? 8 : 9,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  // ─── Save helpers ────────────────────────────────────────────────────────

  /// Saves the PDF document to the Downloads folder (or Documents as fallback)
  /// and returns the file path.  On platforms where path_provider is
  /// unavailable it falls back to Printing.sharePdf.
  Future<String?> _savePdf(pw.Document pdf, String filename) async {
    final bytes = await pdf.save();

    // On web or unsupported platforms fall back to share/print dialog.
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return null;
    }

    try {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      // Last resort: share dialog
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return null;
    }
  }

  // ─── Data helpers ────────────────────────────────────────────────────────

  String _subjectName(List<Subject> subjects, String id) {
    try { return subjects.firstWhere((s) => s.id == id).name; } catch (_) { return '?'; }
  }

  String _teacherName(List<Teacher> teachers, String id) {
    try { return teachers.firstWhere((t) => t.id == id).fullName; } catch (_) { return '?'; }
  }

  /// Converts a Flutter color int to a PdfColor safely.
  PdfColor _subjectPdfColor(List<Subject> subjects, String id) {
    try {
      final colorValue = subjects.firstWhere((s) => s.id == id).colorValue;
      // colorValue is 0xAARRGGBB. We need the 6-char RGB hex (no alpha).
      final hex = colorValue.toRadixString(16).padLeft(8, '0').substring(2);
      return PdfColor.fromHex(hex);
    } catch (_) {
      return PdfColors.grey300;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';

  String _fileDate() {
    final d = DateTime.now();
    return '${d.year}${_p(d.month)}${_p(d.day)}_${_p(d.hour)}${_p(d.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Internal data class ──────────────────────────────────────────────────────

class _CellData {
  final String top;
  final String bottom;
  final PdfColor color;
  const _CellData({required this.top, required this.bottom, required this.color});
}