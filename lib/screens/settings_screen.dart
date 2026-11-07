import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_update_checker.dart';
import '../data/knowledge_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.database,
    this.appUpdateChecker,
    super.key,
  });

  final KnowledgeDatabase database;
  final AppUpdateChecker? appUpdateChecker;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdates = false;

  Future<void> _checkForUpdates() async {
    final checker = widget.appUpdateChecker;
    if (checker == null || _checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final update = await checker.check();
      if (!mounted) return;
      final openRelease = await showDialog<bool>(
        context: context,
        builder: (context) {
          final available = update?.isAvailable ?? false;
          final title = update == null
              ? 'Sin publicaciones disponibles'
              : available
              ? 'Toxo ${update.latestVersion} está disponible'
              : 'Toxo está actualizado';
          final details = update == null
              ? 'No hay una versión publicada en GitHub Releases. Las compilaciones de Actions no son actualizaciones instalables.'
              : available
              ? '${update.releaseName}\n\n${_releaseSummary(update.releaseNotes)}\n\n'
                    'Se abrirá la publicación oficial. Android requiere que confirmes la instalación y que la APK sea compatible y esté firmada con la misma clave que esta app.'
              : 'Versión instalada: ${update.currentVersion}. Última versión publicada: ${update.latestVersion}.';
          return AlertDialog(
            title: Text(title),
            content: Text(details),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cerrar'),
              ),
              if (available)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ver actualización'),
                ),
            ],
          );
        },
      );
      if (openRelease == true && update != null) {
        final launched = await launchUrl(
          update.releaseUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw StateError('No se pudo abrir la publicación oficial en GitHub.');
        }
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo consultar la actualización: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir preferencia'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Por ejemplo: prefiero respuestas breves',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    try {
      widget.database.remember(note);
      setState(() {});
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ?? 'Preferencia no válida.',
          ),
        ),
      );
    }
  }

  Future<void> _clearMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar preferencias'),
        content: const Text('Se eliminarán todas las preferencias guardadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.database.clearMemories();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.database.memoryEnabled;
    final memories = widget.database.memories;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias y privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.appUpdateChecker != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.system_update_alt_rounded),
                title: const Text('Buscar actualización de Toxo'),
                subtitle: const Text(
                  'Consulta GitHub Releases solo cuando lo pidas.',
                ),
                trailing: _checkingUpdates
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _checkingUpdates ? null : _checkForUpdates,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: SwitchListTile(
              title: const Text('Memoria local'),
              subtitle: const Text(
                'Guarda solo preferencias que escribas aquí. Todo queda en este dispositivo.',
              ),
              value: enabled,
              onChanged: (value) {
                widget.database.setMemoryEnabled(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estilo de conversación',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          RadioListTile<String>(
            title: const Text('Cercano'),
            value: 'cercano',
            groupValue: widget.database.style,
            onChanged: (value) {
              if (value == null) return;
              widget.database.setStyle(value);
              setState(() {});
            },
          ),
          RadioListTile<String>(
            title: const Text('Breve'),
            value: 'breve',
            groupValue: widget.database.style,
            onChanged: (value) {
              if (value == null) return;
              widget.database.setStyle(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tus preferencias',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (enabled)
                IconButton(
                  tooltip: 'Añadir preferencia',
                  onPressed: _addMemory,
                  icon: const Icon(Icons.add),
                ),
              if (memories.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar todas',
                  onPressed: _clearMemories,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (!enabled)
            const Text('Activa la memoria para añadir preferencias.'),
          for (final memory in memories)
            Card(
              child: ListTile(
                title: Text(memory.note),
                trailing: IconButton(
                  tooltip: 'Eliminar preferencia',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.database.deleteMemory(memory.id);
                    setState(() {});
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _releaseSummary(String notes) {
    final cleaned = notes.trim();
    if (cleaned.isEmpty) return 'Consulta las notas de la versión en GitHub.';
    return cleaned.length <= 1200 ? cleaned : '${cleaned.substring(0, 1200)}…';
  }
}
