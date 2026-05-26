import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/import_export_service.dart' show sanitiseFilename;

class PdfExportService {
  // ─── Public API ──────────────────────────────────────────────────────────

  /// Exports a section schedule.
  /// [suggestedName] is pre-filled in the native Save-As dialog.
  Future<PdfExportResult> exportSectionSchedule({
    required SectionSchedule schedule,
    required Section section,
    required Grade grade,
    required List<Subject> subjects,
    required List<Teacher> teachers,
    String? suggestedName,
  }) async {
    final pdf  = pw.Document();
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
              style: pw.TextStyle(
                  font: font, fontSize: 10, color: PdfColors.grey600),
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
                  top:    _subjectName(subjects, slot.subjectId),
                  bottom: _teacherName(teachers, slot.teacherId),
                  color:  _subjectPdfColor(subjects, slot.subjectId),
                );
              },
              font: font,
              fontBold: fontBold,
            ),
          ],
        ),
      ),
    );

    final defaultName = suggestedName ??
        'horario_${section.name}_${grade.name}';
    return _savePdf(pdf, defaultName);
  }

  /// Exports a teacher's schedule across all sections.
  Future<PdfExportResult> exportTeacherSchedule({
    required Teacher teacher,
    required List<SectionSchedule> allSchedules,
    required List<Grade> grades,
    required List<Section> sections,
    required List<Subject> subjects,
    String? suggestedName,
  }) async {
    final pdf      = pw.Document();
    final font     = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final config   = grades.isNotEmpty ? grades.first.config : const GradeConfig();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Horario Maestro/a: ${teacher.fullName}',
                style: pw.TextStyle(font: fontBold, fontSize: 16)),
            pw.SizedBox(height: 12),
            _buildTable(
              config: config,
              labelPrefix: 'S',
              dayHeaders: config.classDays,
              cellBuilder: (day, p) {
                String? subjectId;
                final groupLabels = <String>[];
                for (final sched in allSchedules) {
                  final slot = sched.getSlot(day, p);
                  if (slot == null || slot.teacherId != teacher.id) continue;
                  subjectId ??= slot.subjectId;
                  final sec =
                      sections.where((s) => s.id == sched.sectionId).firstOrNull;
                  if (sec != null) {
                    final gr =
                        grades.where((g) => g.id == sec.gradeId).firstOrNull;
                    final label =
                        gr != null ? '${gr.name} ${sec.name}' : sec.name;
                    if (!groupLabels.contains(label)) groupLabels.add(label);
                  }
                }
                if (subjectId == null) return null;
                return _CellData(
                  top:    _subjectName(subjects, subjectId),
                  bottom: groupLabels.isNotEmpty ? groupLabels.join(' / ') : '?',
                  color:  _subjectPdfColor(subjects, subjectId),
                );
              },
              font: font,
              fontBold: fontBold,
            ),
          ],
        ),
      ),
    );

    final defaultName = suggestedName ??
        'horario_maestro_${teacher.fullName}'.replaceAll(' ', '_');
    return _savePdf(pdf, defaultName);
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
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            _pdfCell('Hora / Sesión', fontBold, isHeader: true),
            ...dayHeaders.map((d) => _pdfCell(d, fontBold, isHeader: true)),
          ],
        ),
        ...List.generate(config.sessionsPerDay, (p) {
          return pw.TableRow(
            children: [
              _pdfCell('$labelPrefix${p + 1}  ${labels[p]}', fontBold,
                  small: true),
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
                              font: fontBold,
                              fontSize: 7,
                              color: PdfColors.white)),
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

  // ─── Save helper ─────────────────────────────────────────────────────────

  /// Shows the native Save-As dialog (folder + filename).
  /// [suggestedName] should NOT include the `.pdf` extension.
  Future<PdfExportResult> _savePdf(
      pw.Document pdf, String suggestedName) async {
    final bytes    = await pdf.save();
    final safeName = sanitiseFilename(suggestedName, fallback: 'horario');

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
      return PdfExportResult.ok(null);
    }

    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar horario PDF',
        fileName: '$safeName.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputPath == null) return PdfExportResult.cancelled();

      final finalPath =
          outputPath.endsWith('.pdf') ? outputPath : '$outputPath.pdf';
      final resolvedPath = _resolveNameCollision(finalPath);

      final file = File(resolvedPath);
      await file.writeAsBytes(bytes);
      return PdfExportResult.ok(file.path);
    } catch (e) {
      // Last resort: system share/print dialog.
      try {
        await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
        return PdfExportResult.ok(null);
      } catch (e2) {
        return PdfExportResult.fail('Error al guardar PDF: $e');
      }
    }
  }

  // ─── Name-collision resolver ──────────────────────────────────────────────

  String _resolveNameCollision(String path) {
    if (!File(path).existsSync()) return path;
    final file   = File(path);
    final dir    = file.parent.path;
    final name   = file.uri.pathSegments.last;
    final dotIdx = name.lastIndexOf('.');
    final stem   = dotIdx >= 0 ? name.substring(0, dotIdx) : name;
    final ext    = dotIdx >= 0 ? name.substring(dotIdx)    : '';

    int counter = 2;
    while (true) {
      final candidate = '$dir/${stem}_($counter)$ext';
      if (!File(candidate).existsSync()) return candidate;
      counter++;
    }
  }

  // ─── Data helpers ────────────────────────────────────────────────────────

  String _subjectName(List<Subject> subjects, String id) {
    try {
      return subjects.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return '?';
    }
  }

  String _teacherName(List<Teacher> teachers, String id) {
    try {
      return teachers.firstWhere((t) => t.id == id).fullName;
    } catch (_) {
      return '?';
    }
  }

  PdfColor _subjectPdfColor(List<Subject> subjects, String id) {
    try {
      final colorValue = subjects.firstWhere((s) => s.id == id).colorValue;
      final hex =
          colorValue.toRadixString(16).padLeft(8, '0').substring(2);
      return PdfColor.fromHex(hex);
    } catch (_) {
      return PdfColors.grey300;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Result type ─────────────────────────────────────────────────────────────

class PdfExportResult {
  final String? savedPath;
  final bool success;
  final String? error;

  const PdfExportResult._({this.savedPath, required this.success, this.error});

  factory PdfExportResult.ok(String? path) =>
      PdfExportResult._(savedPath: path, success: true);

  factory PdfExportResult.fail(String error) =>
      PdfExportResult._(success: false, error: error);

  factory PdfExportResult.cancelled() =>
      PdfExportResult._(success: false, error: null);

  bool get cancelled => !success && error == null;
}

// ─── Internal data class ──────────────────────────────────────────────────────

class _CellData {
  final String top;
  final String bottom;
  final PdfColor color;
  const _CellData(
      {required this.top, required this.bottom, required this.color});
}