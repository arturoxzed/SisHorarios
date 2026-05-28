import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistema_horarios/providers/app_provider.dart';
import 'package:sistema_horarios/theme/app_theme.dart';
import 'package:sistema_horarios/services/import_export_service.dart'
    show sanitiseFilename;

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class ImportExportDialog extends StatefulWidget {
  const ImportExportDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const ImportExportDialog(),
      );

  @override
  State<ImportExportDialog> createState() => _ImportExportDialogState();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ImportExportDialogState extends State<ImportExportDialog> {
  bool _includeSchedules = true;
  bool _busy             = false;
  _FeedbackMessage? _feedback;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Returns a default filename stem (no extension, no timestamp — the user
  /// will customise it in the Save-As dialog).
  String _defaultJsonName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_p(now.month)}${_p(now.day)}_${_p(now.hour)}${_p(now.minute)}';
    return 'school_config_v1_$stamp';
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _doExport() async {
    // ── Ask the user for a filename stem ─────────────────────────────────────
    final suggested = await _showFilenameDialog(
      title:       'Nombre del archivo JSON',
      initialName: _defaultJsonName(),
      extension:   '.json',
    );
    if (suggested == null) return; // user cancelled

    setState(() {
      _busy     = true;
      _feedback = null;
    });

    final provider = context.read<AppProvider>();
    final result   = await provider.exportConfig(
      includeSchedules: _includeSchedules,
      suggestedName:    suggested,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.cancelled) {
        // User closed the native Save-As dialog — no extra feedback needed.
        return;
      }
      if (result.success) {
        _feedback = _FeedbackMessage.success(
          result.savedPath != null
              ? 'Archivo guardado en:\n${result.savedPath}'
              : 'Archivo listo para descarga.',
        );
      } else {
        _feedback =
            _FeedbackMessage.error(result.error ?? 'Error desconocido.');
      }
    });
  }

  Future<void> _doImport() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() {
      _busy     = true;
      _feedback = null;
    });

    final provider = context.read<AppProvider>();
    final result   = await provider.importConfig();

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.cancelled) return;

    if (result.success) {
      setState(() => _feedback = _FeedbackMessage.success(
          'Importación completada. Los datos anteriores fueron reemplazados.'));
    } else {
      setState(() =>
          _feedback = _FeedbackMessage.error(result.error ?? 'Error desconocido.'));
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  /// Shows an inline text-field dialog so the user can personalise the
  /// filename before the native Save-As picker opens.
  ///
  /// Returns the sanitised stem (no extension), or null if cancelled.
  Future<String?> _showFilenameDialog({
    required String title,
    required String initialName,
    required String extension,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _FilenameDialog(
        title: title,
        initialName: initialName,
        extension: extension,
      ),
    );
  }

  Future<bool> _showConfirmDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar importación'),
        content: const Text(
          'Importar un archivo reemplazará TODA la configuración actual '
          '(niveles, grados, materias, maestros y horarios).\n\n'
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, importar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.import_export_rounded, size: 22),
          SizedBox(width: 8),
          Text('Importar / Exportar'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Export section ──────────────────────────────────────────────
            _SectionHeader('Exportar configuración'),
            const SizedBox(height: 8),
            const Text(
              'Guarda toda la configuración escolar en un archivo JSON. '
              'Podrás elegir el nombre y la carpeta de destino.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir horarios generados',
                  style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                'Desactiva para exportar solo la estructura (niveles, grupos, '
                'materias, maestros).',
                style: TextStyle(fontSize: 11),
              ),
              value: _includeSchedules,
              onChanged:
                  _busy ? null : (v) => setState(() => _includeSchedules = v),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Exportar a JSON…'),
              onPressed: _busy ? null : _doExport,
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // ── Import section ──────────────────────────────────────────────
            _SectionHeader('Importar configuración'),
            const SizedBox(height: 8),
            const Text(
              'Carga un archivo JSON exportado previamente. '
              'Esto reemplazará todos los datos actuales.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Seleccionar archivo JSON…'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warning,
                side: const BorderSide(color: AppTheme.warning),
              ),
              onPressed: _busy ? null : _doImport,
            ),

            // ── Feedback ────────────────────────────────────────────────────
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 14),
              _FeedbackBanner(message: _feedback!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILENAME DIALOG  —  StatefulWidget para gestionar el TextEditingController
// ─────────────────────────────────────────────────────────────────────────────

class _FilenameDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String extension;

  const _FilenameDialog({
    required this.title,
    required this.initialName,
    required this.extension,
  });

  @override
  State<_FilenameDialog> createState() => _FilenameDialogState();
}

class _FilenameDialogState extends State<_FilenameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose(); // se llama cuando el widget sale del árbol, seguro
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, sanitiseFilename(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escribe el nombre del archivo (sin la extensión ${widget.extension}).\n'
                'Después podrás elegir la carpeta de destino.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  suffixText: widget.extension,
                  hintText: 'ej. horario_escuela_2025',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre no puede estar vacío.';
                  }
                  if (sanitiseFilename(v.trim()).isEmpty) {
                    return 'El nombre contiene solo caracteres inválidos.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}



class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      );
}

class _FeedbackMessage {
  final String text;
  final bool isError;
  const _FeedbackMessage._(this.text, this.isError);
  factory _FeedbackMessage.success(String text) =>
      _FeedbackMessage._(text, false);
  factory _FeedbackMessage.error(String text) =>
      _FeedbackMessage._(text, true);
}

class _FeedbackBanner extends StatelessWidget {
  final _FeedbackMessage message;
  const _FeedbackBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final color = message.isError ? AppTheme.error : AppTheme.success;
    final icon  = message.isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: TextStyle(fontSize: 12, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}