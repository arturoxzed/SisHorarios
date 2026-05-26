import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERSIONING
// ─────────────────────────────────────────────────────────────────────────────

const int _currentVersion = 1;

// ─────────────────────────────────────────────────────────────────────────────
// FILE-NAME SANITISER
// ─────────────────────────────────────────────────────────────────────────────

/// Removes characters that are illegal in Windows/macOS/Linux filenames and
/// collapses runs of spaces/underscores so the result is always safe to use
/// directly as a file name (without path separators).
String sanitiseFilename(String raw, {String fallback = 'archivo'}) {
  // Characters forbidden on Windows: \ / : * ? " < > |
  // We also strip control characters and leading/trailing dots or spaces.
  var s = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '')
      .replaceAll(RegExp(r'_+'), '_')   // collapse repeated underscores
      .replaceAll(RegExp(r'\s+'), '_')  // spaces → underscore
      .replaceAll(RegExp(r'^[.\s_]+|[.\s_]+$'), ''); // trim leading/trailing . _ space
  return s.isEmpty ? fallback : s;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHOOL CONFIG
// ─────────────────────────────────────────────────────────────────────────────

class SchoolConfig {
  final List<EducationalLevel> levels;
  final List<Grade> grades;
  final List<Subject> subjects;
  final List<Teacher> teachers;
  final List<SectionSchedule> schedules;

  const SchoolConfig({
    required this.levels,
    required this.grades,
    required this.subjects,
    required this.teachers,
    this.schedules = const [],
  });

  Map<String, dynamic> toJson() => {
        'version': _currentVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': {
          'levels':    levels.map((e) => e.toJson()).toList(),
          'grades':    grades.map((e) => e.toJson()).toList(),
          'subjects':  subjects.map((e) => e.toJson()).toList(),
          'teachers':  teachers.map((e) => e.toJson()).toList(),
          'schedules': schedules.map((e) => e.toJson()).toList(),
        },
      };

  factory SchoolConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version == null) {
      throw const ImportExportException(
        'El archivo no contiene un campo "version". '
        'Es posible que no sea un archivo de configuración válido.',
        ImportExportErrorKind.invalidFormat,
      );
    }
    if (version is! int) {
      throw ImportExportException(
        'El campo "version" debe ser un entero, pero se encontró: $version',
        ImportExportErrorKind.invalidFormat,
      );
    }
    if (version > _currentVersion) {
      throw ImportExportException(
        'Este archivo fue creado con una versión más reciente de la app '
        '(versión $version). Actualiza la aplicación para poder importarlo.',
        ImportExportErrorKind.incompatibleVersion,
      );
    }

    final raw = json['data'];
    if (raw == null || raw is! Map<String, dynamic>) {
      throw const ImportExportException(
        'El archivo no contiene el bloque "data" esperado.',
        ImportExportErrorKind.invalidFormat,
      );
    }

    try {
      return SchoolConfig(
        levels:    _parseList(raw, 'levels',    EducationalLevel.fromJson),
        grades:    _parseList(raw, 'grades',    Grade.fromJson),
        subjects:  _parseList(raw, 'subjects',  Subject.fromJson),
        teachers:  _parseList(raw, 'teachers',  Teacher.fromJson),
        schedules: _parseList(raw, 'schedules', SectionSchedule.fromJson),
      );
    } on ImportExportException {
      rethrow;
    } catch (e) {
      throw ImportExportException(
        'Los datos están corruptos o tienen un formato inesperado: $e',
        ImportExportErrorKind.corruptData,
      );
    }
  }

  static List<T> _parseList<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) factory,
  ) {
    final raw = data[key];
    if (raw == null) return [];
    if (raw is! List) {
      throw ImportExportException(
        'Se esperaba una lista para "$key" pero se encontró: ${raw.runtimeType}',
        ImportExportErrorKind.corruptData,
      );
    }
    return raw.cast<Map<String, dynamic>>().map(factory).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────

enum ImportExportErrorKind {
  invalidFormat,
  incompatibleVersion,
  corruptData,
  fileSystem,
  cancelled,
}

class ImportExportException implements Exception {
  final String message;
  final ImportExportErrorKind kind;
  const ImportExportException(this.message, this.kind);

  @override
  String toString() => 'ImportExportException($kind): $message';
}

class ExportResult {
  final String? savedPath;
  final bool success;
  final String? error;

  const ExportResult._({this.savedPath, required this.success, this.error});

  factory ExportResult.ok(String? path) =>
      ExportResult._(savedPath: path, success: true);

  factory ExportResult.fail(String error) =>
      ExportResult._(success: false, error: error);

  /// User dismissed the native save dialog without picking a location.
  factory ExportResult.cancelled() =>
      ExportResult._(success: false, error: null);

  bool get cancelled => !success && error == null;
}

class ImportResult {
  final SchoolConfig? config;
  final bool success;
  final String? error;
  final bool cancelled;

  const ImportResult._({
    this.config,
    required this.success,
    this.error,
    this.cancelled = false,
  });

  factory ImportResult.ok(SchoolConfig config) =>
      ImportResult._(config: config, success: true);

  factory ImportResult.fail(String error) =>
      ImportResult._(success: false, error: error);

  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ImportExportService {
  // ── Export ────────────────────────────────────────────────────────────────

  /// Shows the native "Save As" dialog so the user can choose both the folder
  /// and the filename.  [suggestedName] is pre-filled in the dialog (without
  /// the `.json` extension — the picker adds it via [allowedExtensions]).
  ///
  /// On web it falls back to an in-memory download (path_provider unavailable).
  Future<ExportResult> exportConfig(
    SchoolConfig config, {
    String suggestedName = 'school_config',
  }) async {
    try {
      final encoded =
          const JsonEncoder.withIndent('  ').convert(config.toJson());
      final bytes = utf8.encode(encoded);

      if (kIsWeb) {
        // Web: no native file-system picker — just return success and let
        // the caller handle the download through a browser-specific helper.
        return ExportResult.ok(null);
      }

      // ── Desktop / mobile: show native Save-As dialog ──────────────────────
      final safeName = sanitiseFilename(suggestedName, fallback: 'school_config');

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar configuración JSON',
        fileName: '$safeName.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes, // FilePicker writes on some platforms; we write below.
      );

      if (outputPath == null) return ExportResult.cancelled();

      // Ensure the extension is present (some platforms strip it).
      final finalPath =
          outputPath.endsWith('.json') ? outputPath : '$outputPath.json';

      // Resolve name collisions by appending a counter.
      final resolvedPath = _resolveNameCollision(finalPath);

      final file = File(resolvedPath);
      await file.writeAsBytes(bytes, flush: true);
      return ExportResult.ok(file.path);
    } on ImportExportException catch (e) {
      return ExportResult.fail(e.message);
    } catch (e) {
      return ExportResult.fail('Error al exportar: $e');
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<ImportResult> importConfig() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
        dialogTitle: 'Seleccionar archivo de configuración JSON',
      );
    } catch (e) {
      return ImportResult.fail('No se pudo abrir el selector de archivos: $e');
    }

    if (picked == null || picked.files.isEmpty) return ImportResult.cancelled();

    final file = picked.files.first;

    String raw;
    try {
      if (file.bytes != null) {
        raw = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        raw = await File(file.path!).readAsString(encoding: utf8);
      } else {
        return ImportResult.fail(
            'No se pudo leer el archivo seleccionado (sin datos ni ruta).');
      }
    } catch (e) {
      return ImportResult.fail('Error al leer el archivo: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e) {
      return ImportResult.fail(
          'El archivo no contiene JSON válido: ${e.message}');
    } catch (e) {
      return ImportResult.fail('Error inesperado al decodificar el archivo: $e');
    }

    try {
      final config = SchoolConfig.fromJson(decoded);
      return ImportResult.ok(config);
    } on ImportExportException catch (e) {
      return ImportResult.fail(e.message);
    } catch (e) {
      return ImportResult.fail('Los datos del archivo son inválidos: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// If [path] already exists on disk, appends _(2), _(3), … until a free
  /// name is found.
  String _resolveNameCollision(String path) {
    if (!File(path).existsSync()) return path;

    final file = File(path);
    final dir  = file.parent.path;
    // Split stem and extension properly.
    final name = file.uri.pathSegments.last; // e.g. "config.json"
    final dotIdx = name.lastIndexOf('.');
    final stem = dotIdx >= 0 ? name.substring(0, dotIdx) : name;
    final ext  = dotIdx >= 0 ? name.substring(dotIdx)    : '';

    int counter = 2;
    while (true) {
      final candidate = '$dir/${stem}_($counter)$ext';
      if (!File(candidate).existsSync()) return candidate;
      counter++;
    }
  }
}